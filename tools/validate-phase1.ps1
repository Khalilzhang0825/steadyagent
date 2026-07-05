[CmdletBinding()]
param(
    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $Root) {
    $Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
else {
    $Root = (Resolve-Path $Root).Path
}

$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Detail
    )

    $checks.Add([PSCustomObject]@{
        Name = $Name
        Passed = $Passed
        Detail = $Detail
    }) | Out-Null
}

function Read-Text {
    param([string]$RelativePath)

    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return $null
    }
    return Get-Content -LiteralPath $path -Raw
}

function Test-Contains {
    param(
        [string]$Label,
        [string]$Text,
        [string]$Pattern
    )

    Add-Check $Label (($null -ne $Text) -and ($Text -match $Pattern)) "Missing required content"
}

function Test-NoPattern {
    param(
        [string]$Label,
        [string]$Text,
        [string]$Pattern
    )

    Add-Check $Label (($null -ne $Text) -and (-not ($Text -match $Pattern))) "Unexpected content found"
}

function Get-HeadingIndexByLabel {
    param(
        [string]$Text,
        [string]$Label
    )

    if ($null -eq $Text) {
        return -1
    }

    $pattern = "(?m)^##[^\r\n]*" + [regex]::Escape($Label) + "[^\r\n]*$"
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) {
        return -1
    }

    return $match.Index
}

function Get-SectionByLabel {
    param(
        [string]$Text,
        [string]$Label
    )

    if ($null -eq $Text) {
        return $null
    }

    $pattern = "(?ms)^##[^\r\n]*" + [regex]::Escape($Label) + "[^\r\n]*\r?\n(.*?)(?=^##\s|\z)"
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) {
        return $null
    }

    return $match.Groups[1].Value
}

function Get-LineContaining {
    param(
        [string]$Text,
        [string]$Needle
    )

    if ($null -eq $Text) {
        return ""
    }

    foreach ($line in ($Text -split "\r?\n")) {
        if ($line.Contains($Needle)) {
            return $line.Trim()
        }
    }

    return ""
}

function Test-SectionContains {
    param(
        [string]$Label,
        [string]$Section,
        [string]$Pattern
    )

    Add-Check $Label (($null -ne $Section) -and ($Section -match $Pattern)) "Missing required section content"
}

function Test-SectionExcludes {
    param(
        [string]$Label,
        [string]$Section,
        [string]$Pattern
    )

    Add-Check $Label (($null -ne $Section) -and (-not ($Section -match $Pattern))) "Planned-only content appears in the wrong section"
}

function Test-SectionOrder {
    param(
        [string]$Label,
        [string]$Text,
        [string[]]$Labels
    )

    $previous = -1
    $missing = New-Object System.Collections.Generic.List[string]
    $outOfOrder = New-Object System.Collections.Generic.List[string]

    foreach ($sectionLabel in $Labels) {
        $index = Get-HeadingIndexByLabel $Text $sectionLabel
        if ($index -lt 0) {
            $missing.Add($sectionLabel) | Out-Null
            continue
        }
        if ($index -lt $previous) {
            $outOfOrder.Add($sectionLabel) | Out-Null
        }
        $previous = $index
    }

    $passed = ($missing.Count -eq 0) -and ($outOfOrder.Count -eq 0)
    $detail = if ($passed) { "OK" } else { "Missing: " + ($missing -join ", ") + "; out of order: " + ($outOfOrder -join ", ") }
    Add-Check $Label $passed $detail
}

function Test-NoPatternInFiles {
    param(
        [string]$Label,
        [string[]]$RelativePaths,
        [string]$Pattern
    )

    $hits = New-Object System.Collections.Generic.List[string]
    foreach ($relative in $RelativePaths) {
        $text = Read-Text $relative
        if (($null -ne $text) -and ($text -match $Pattern)) {
            $hits.Add($relative) | Out-Null
        }
    }

    Add-Check $Label ($hits.Count -eq 0) ($(if ($hits.Count -eq 0) { "OK" } else { "Matched: " + ($hits -join ", ") }))
}

function Test-LinkTarget {
    param(
        [string]$Label,
        [string]$RelativePath
    )

    $path = Join-Path $Root $RelativePath
    Add-Check $Label (Test-Path -LiteralPath $path -PathType Leaf) "Missing linked file: $RelativePath"
}

function Test-OnlyExpectedChangedFiles {
    param([string[]]$ExpectedFiles)

    Push-Location $Root
    try {
        $status = & git status --porcelain --untracked-files=all
        $code = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    if ($code -ne 0) {
        Add-Check "git status is readable" $false "git status failed"
        return
    }

    $expected = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($file in $ExpectedFiles) {
        [void]$expected.Add(($file -replace "\\", "/"))
    }

    $unexpected = New-Object System.Collections.Generic.List[string]
    foreach ($line in $status) {
        if (-not $line -or $line.Length -lt 4) {
            continue
        }
        $path = $line.Substring(3).Trim()
        if ($path -match " -> ") {
            $parts = $path -split " -> "
            $path = $parts[$parts.Count - 1].Trim()
        }
        $path = $path -replace "\\", "/"
        if (-not $expected.Contains($path)) {
            $unexpected.Add($path) | Out-Null
        }
    }

    Add-Check "worktree changes are limited to Phase 1 files" ($unexpected.Count -eq 0) ($(if ($unexpected.Count -eq 0) { "OK" } else { "Unexpected: " + ($unexpected -join ", ") }))
}

$phase1Files = @(
    "README.md",
    "README.zh-CN.md",
    "PROJECT_STATE.md",
    "tools/validate-phase1.ps1"
)

$readme = Read-Text "README.md"
$readmeZh = Read-Text "README.zh-CN.md"
$readmeAvailable = Get-SectionByLabel $readme "Available Today"
$readmePlanned = Get-SectionByLabel $readme "Planned For v1"
$readmeQuickStart = Get-SectionByLabel $readme "Quick Start"
$readmeZhAvailable = Get-SectionByLabel $readmeZh "Available Today"
$readmeZhPlanned = Get-SectionByLabel $readmeZh "Planned For v1"
$readmeZhQuickStart = Get-SectionByLabel $readmeZh "Quick Start"
$quickStartCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-phase1.ps1"
$readmeQuickStartCommand = Get-LineContaining $readmeQuickStart $quickStartCommand
$readmeZhQuickStartCommand = Get-LineContaining $readmeZhQuickStart $quickStartCommand

Test-OnlyExpectedChangedFiles $phase1Files
Add-Check "README.md exists" ($null -ne $readme) "Missing README.md"
Add-Check "README.md is SteadyAgent-first" (($readme -match "(?m)^# SteadyAgent\b") -and ($readme -match "Ship with evidence, not vibes[.]")) "Missing SteadyAgent title or tagline"
Add-Check "README.md no longer presents the legacy project as the main product" (-not ($readme -match "(?m)^# .+AI Coding Agent")) "Legacy title still present"
Add-Check "README.zh-CN.md exists" ($null -ne $readmeZh) "Missing README.zh-CN.md"
Add-Check "README.zh-CN.md is SteadyAgent-first" (($readmeZh -match "(?m)^# SteadyAgent\b") -and ($readmeZh -match "Ship with evidence, not vibes[.]")) "Missing Chinese README title or tagline"

$sectionLabels = @(
    "Why SteadyAgent",
    "Available Today",
    "Planned For v1",
    "The Loop",
    "Quick Start",
    "Safety Model",
    "Compatibility",
    "What SteadyAgent Is Not",
    "Current v1 Plan",
    "Who This Is For",
    "Design Principles",
    "Resume Case Study",
    "License"
)

foreach ($heading in $sectionLabels) {
    Test-Contains "README.md has section: $heading" $readme ("(?m)^## " + [regex]::Escape($heading) + "\b")
    Add-Check "README.zh-CN.md has paired section label: $heading" ((Get-HeadingIndexByLabel $readmeZh $heading) -ge 0) "Missing paired section label"
}

Test-SectionOrder "README.md section order matches Phase 1 narrative" $readme $sectionLabels
Test-SectionOrder "README.zh-CN.md section order matches README.md labels" $readmeZh $sectionLabels

foreach ($term in @(
    "local-first harness",
    "Codex",
    "Claude Code",
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-phase1.ps1",
    "docs/v1-migration-plan.md",
    "dry-run installer",
    "checkpoint",
    "independent review",
    "not packaged as an installer yet"
)) {
    Test-Contains "README.md contains: $term" $readme ([regex]::Escape($term))
}

foreach ($term in @(
    "README.md",
    "Codex",
    "Claude Code",
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-phase1.ps1",
    "docs/v1-migration-plan.md",
    "dry-run",
    "checkpoint",
    "harness engineering",
    "Available Today",
    "Planned For v1",
    "Compatibility",
    "What SteadyAgent Is Not",
    "not packaged as an installer yet"
)) {
    Test-Contains "README.zh-CN.md contains: $term" $readmeZh ([regex]::Escape($term))
}

Test-LinkTarget "README zh link target exists" "README.zh-CN.md"
Test-LinkTarget "migration plan link target exists" "docs/v1-migration-plan.md"

Test-NoPattern "README.md does not point Quick Start at Phase 0 validation" $readme ([regex]::Escape("validate-phase0.ps1"))
Test-NoPattern "README.zh-CN.md does not point Quick Start at Phase 0 validation" $readmeZh ([regex]::Escape("validate-phase0.ps1"))
Test-NoPattern "README.md does not require unpublished local branch checkout" $readme ([regex]::Escape("git switch codex/steadyagent-v1"))
Test-NoPattern "README.zh-CN.md does not require unpublished local branch checkout" $readmeZh ([regex]::Escape("git switch codex/steadyagent-v1"))

Test-SectionContains "README.md Quick Start contains Phase 1 command" $readmeQuickStart ([regex]::Escape($quickStartCommand))
Test-SectionContains "README.zh-CN.md Quick Start contains Phase 1 command" $readmeZhQuickStart ([regex]::Escape($quickStartCommand))
Add-Check "Quick Start command matches across English and Chinese README" (($readmeQuickStartCommand -ne "") -and ($readmeQuickStartCommand -eq $readmeZhQuickStartCommand)) "Quick Start command differs across languages"

foreach ($term in @(
    "English README",
    "Chinese README",
    "docs/v1-migration-plan.md",
    "Phase 0 and Phase 1 validation scripts",
    "independent review gate"
)) {
    Test-SectionContains "README.md Available Today contains current asset: $term" $readmeAvailable ([regex]::Escape($term))
}

foreach ($term in @(
    "README",
    "docs/v1-migration-plan.md",
    "Phase 0",
    "Phase 1",
    "TDD",
    "independent review"
)) {
    Test-SectionContains "README.zh-CN.md Available Today contains current asset: $term" $readmeZhAvailable ([regex]::Escape($term))
}

foreach ($term in @(
    "dry-run installer",
    "Git preflight and checkpoint scripts",
    "hook-based safety guards",
    "project state recovery",
    "short always-on instructions",
    "progressive rules"
)) {
    Test-SectionContains "README.md Planned For v1 contains planned asset: $term" $readmePlanned ([regex]::Escape($term))
    Test-SectionExcludes "README.md Available Today excludes planned-only asset: $term" $readmeAvailable ([regex]::Escape($term))
}

foreach ($term in @(
    "dry-run",
    "hooks",
    "Codex",
    "Claude Code"
)) {
    Test-SectionContains "README.zh-CN.md Planned For v1 contains planned asset token: $term" $readmeZhPlanned ([regex]::Escape($term))
    Test-SectionExcludes "README.zh-CN.md Available Today excludes planned-only token: $term" $readmeZhAvailable ([regex]::Escape($term))
}

$slash = [string][char]47
$backslash = [string][char]92
$privatePathPattern = "(?i)(" + "C:" + [regex]::Escape($backslash + "Users" + $backslash) + "|" + [regex]::Escape($slash + "Users" + $slash) + "|E:" + [regex]::Escape($backslash) + "|D:" + [regex]::Escape($backslash) + ")"
$placeholderPattern = "(?i)(" + "TO" + "DO|TB" + "D|lorem " + "ipsum|your[-_ ]?name|replace " + "me)"
$secretPattern = "(?i)(" + "api" + "[_-]?key|access" + "[_-]?token|secret" + "[_-]?key|pass" + "word\s*=|BEGIN (RSA|OPENSSH|PRIVATE) KEY)"

Test-NoPatternInFiles "Phase 1 files have no local absolute private paths" $phase1Files $privatePathPattern
Test-NoPatternInFiles "Phase 1 files have no obvious placeholders" $phase1Files $placeholderPattern
Test-NoPatternInFiles "Phase 1 files have no obvious secret material" $phase1Files $secretPattern

$failed = @($checks | Where-Object { -not $_.Passed })
foreach ($check in $checks) {
    $status = if ($check.Passed) { "PASS" } else { "FAIL" }
    $detail = if ($check.Passed) { "OK" } else { $check.Detail }
    Write-Host ("{0} {1} - {2}" -f $status, $check.Name, $detail)
}

Write-Host ""
Write-Host ("RESULT pass={0} fail={1}" -f ($checks.Count - $failed.Count), $failed.Count)

if ($failed.Count -gt 0) {
    exit 1
}
