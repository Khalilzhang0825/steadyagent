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

function Test-FileExists {
    param([string]$RelativePath)

    $path = Join-Path $Root $RelativePath
    Add-Check "$RelativePath exists" (Test-Path -LiteralPath $path -PathType Leaf) "Missing file"
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

    Add-Check "worktree changes are limited to Phase 2 files" ($unexpected.Count -eq 0) ($(if ($unexpected.Count -eq 0) { "OK" } else { "Unexpected: " + ($unexpected -join ", ") }))
}

$templateFiles = @(
    "templates/codex/AGENTS.md",
    "templates/claude/CLAUDE.md"
)

$ruleFiles = @(
    "rules/README.md",
    "rules/README.zh-CN.md",
    "rules/workflow-routing.md",
    "rules/verification.md",
    "rules/review-gates.md",
    "rules/context-management.md",
    "rules/safety-boundaries.md"
)

$phase2Files = @(
    "README.md",
    "README.zh-CN.md",
    "PROJECT_STATE.md",
    "tools/validate-phase2.ps1"
) + $templateFiles + $ruleFiles

$publicPhase2Files = @(
    "README.md",
    "README.zh-CN.md"
) + $templateFiles + $ruleFiles

Test-OnlyExpectedChangedFiles $phase2Files

foreach ($file in $phase2Files) {
    Test-FileExists $file
}

$readme = Read-Text "README.md"
$readmeZh = Read-Text "README.zh-CN.md"
$available = Get-SectionByLabel $readme "Available Today"
$availableZh = Get-SectionByLabel $readmeZh "Available Today"
$planned = Get-SectionByLabel $readme "Planned For v1"
$plannedZh = Get-SectionByLabel $readmeZh "Planned For v1"

Test-Contains "README.md Available Today lists public templates" $available "templates/"
Test-Contains "README.md Available Today lists progressive rules" $available "rules/"
Test-Contains "README.md Quick Start points at Phase 2 validation" $readme ([regex]::Escape("powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-phase2.ps1"))
Test-Contains "README.zh-CN.md Available Today lists public templates" $availableZh "templates/"
Test-Contains "README.zh-CN.md Available Today lists progressive rules" $availableZh "rules/"
Test-Contains "README.zh-CN.md Quick Start points at Phase 2 validation" $readmeZh ([regex]::Escape("powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-phase2.ps1"))

foreach ($term in @(
    "Git preflight and checkpoint scripts",
    "hook-based safety guards",
    "dry-run installer",
    "skill packaging",
    "fresh-clone release instructions"
)) {
    Test-SectionContains "README.md Planned For v1 contains planned-only asset: $term" $planned ([regex]::Escape($term))
    Test-SectionExcludes "README.md Available Today excludes planned-only asset: $term" $available ([regex]::Escape($term))
}

foreach ($term in @(
    "Git",
    "hooks",
    "dry-run",
    "skill",
    "fresh-clone"
)) {
    Test-SectionContains "README.zh-CN.md Planned For v1 contains planned-only token: $term" $plannedZh ([regex]::Escape($term))
    Test-SectionExcludes "README.zh-CN.md Available Today excludes planned-only token: $term" $availableZh ([regex]::Escape($term))
}

$codexTemplate = Read-Text "templates/codex/AGENTS.md"
$claudeTemplate = Read-Text "templates/claude/CLAUDE.md"

foreach ($term in @(
    "SteadyAgent",
    'Copy this template together with the `rules/` directory',
    "Core Loop",
    "When To Load Rules",
    "rules/",
    "verify behavior",
    "checkpoint",
    "Do not run destructive Git commands"
)) {
    Test-Contains "Codex template contains: $term" $codexTemplate ([regex]::Escape($term))
}

foreach ($term in @(
    "Codex",
    "no pre-tool hook",
    "Git hooks",
    "ask before push"
)) {
    Test-Contains "Codex template documents host boundary: $term" $codexTemplate ([regex]::Escape($term))
}

foreach ($term in @(
    "SteadyAgent",
    "Claude Code",
    'Copy this template together with the `rules/` directory',
    "Core Loop",
    "When To Load Rules",
    "rules/",
    "hooks",
    "subagents",
    "verify behavior"
)) {
    Test-Contains "Claude template contains: $term" $claudeTemplate ([regex]::Escape($term))
}

foreach ($rule in $ruleFiles) {
    $text = Read-Text $rule
    if ($rule -like "rules/README*") {
        Test-Contains "$rule contains SteadyAgent" $text "SteadyAgent"
        Test-Contains "$rule lists workflow-routing" $text "workflow-routing[.]md"
        continue
    }

    foreach ($heading in @("Purpose", "Use When", "Rules", "Validation")) {
        Test-Contains "$rule has section: $heading" $text ("(?m)^## " + [regex]::Escape($heading) + "\b")
    }
}

$workflowRule = Read-Text "rules/workflow-routing.md"
Test-Contains "workflow routing includes core loop" $workflowRule "understand -> plan -> red check -> smallest change -> green check -> review -> checkpoint"
Test-Contains "workflow routing mentions conflicts" $workflowRule "conflict"

$verificationRule = Read-Text "rules/verification.md"
Test-Contains "verification rule checks behavior" $verificationRule "behavior"
Test-Contains "verification rule handles skipped checks" $verificationRule "skipped"

$reviewRule = Read-Text "rules/review-gates.md"
Test-Contains "review rule includes score floor" $reviewRule "9[.]5"
Test-Contains "review rule includes P0/P1 gate" $reviewRule "P0/P1"
Test-Contains "review rule requires findings first" $reviewRule "Findings first"

$contextRule = Read-Text "rules/context-management.md"
Test-Contains "context rule mentions PROJECT_STATE" $contextRule "PROJECT_STATE[.]md"
Test-Contains "context rule mentions compaction" $contextRule "compaction"

$safetyRule = Read-Text "rules/safety-boundaries.md"
Test-Contains "safety rule mentions Codex" $safetyRule "Codex"
Test-Contains "safety rule mentions Claude Code" $safetyRule "Claude Code"
Test-Contains "safety rule blocks destructive Git" $safetyRule "destructive Git"
Test-Contains "safety rule mentions secrets" $safetyRule "secrets"

$slash = [string][char]47
$backslash = [string][char]92
$privatePathPattern = "(?i)(" + "C:" + [regex]::Escape($backslash + "Users" + $backslash) + "|" + [regex]::Escape($slash + "Users" + $slash) + "|E:" + [regex]::Escape($backslash) + "|D:" + [regex]::Escape($backslash) + ")"
$placeholderPattern = "(?i)(" + "TO" + "DO|TB" + "D|lorem " + "ipsum|your[-_ ]?name|replace " + "me)"
$secretPattern = "(?i)(" + "api" + "[_-]?key|access" + "[_-]?token|secret" + "[_-]?key|pass" + "word\s*=|BEGIN (RSA|OPENSSH|PRIVATE) KEY)"

Test-NoPatternInFiles "Phase 2 files have no local absolute private paths" $phase2Files $privatePathPattern
Test-NoPatternInFiles "Phase 2 files have no obvious placeholders" $phase2Files $placeholderPattern
Test-NoPatternInFiles "Phase 2 files have no obvious secret material" $phase2Files $secretPattern
$legacySkillPattern = "zsh" + "-agent-workflow"
$legacyRepoPattern = "zsh" + "-agent-rules"
Test-NoPatternInFiles "Phase 2 files do not use legacy skill name" $phase2Files $legacySkillPattern
Test-NoPatternInFiles "Phase 2 public user files do not use legacy repository name" $publicPhase2Files $legacyRepoPattern

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
