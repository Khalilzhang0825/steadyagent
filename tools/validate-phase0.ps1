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

function Test-FileContains {
    param(
        [string]$RelativePath,
        [string[]]$RequiredPatterns
    )

    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Check $RelativePath $false "Missing file"
        return
    }

    $text = Get-Content -LiteralPath $path -Raw
    foreach ($pattern in $RequiredPatterns) {
        $matched = $text -match $pattern
        Add-Check "$RelativePath contains $pattern" $matched ($(if ($matched) { "OK" } else { "Missing required section or term" }))
    }
}

function Test-GitFact {
    param(
        [string]$Name,
        [string[]]$GitArgs,
        [scriptblock]$Predicate,
        [string]$Detail
    )

    Push-Location $Root
    try {
        $output = & git @GitArgs 2>$null
        $code = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    $passed = ($code -eq 0) -and (& $Predicate $output)
    Add-Check $Name $passed ($(if ($passed) { "OK" } else { $Detail }))
}

function Test-NoPatternInFiles {
    param(
        [string]$Name,
        [string[]]$RelativePaths,
        [string]$Pattern
    )

    $hits = New-Object System.Collections.Generic.List[string]
    foreach ($relative in $RelativePaths) {
        $path = Join-Path $Root $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            continue
        }
        $text = Get-Content -LiteralPath $path -Raw
        if ($text -match $Pattern) {
            $hits.Add($relative) | Out-Null
        }
    }

    Add-Check $Name ($hits.Count -eq 0) ($(if ($hits.Count -eq 0) { "OK" } else { "Matched: " + ($hits -join ", ") }))
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

    Add-Check "worktree changes are limited to Phase 0 files" ($unexpected.Count -eq 0) ($(if ($unexpected.Count -eq 0) { "OK" } else { "Unexpected: " + ($unexpected -join ", ") }))
}

$phase0Files = @(
    "PROJECT_STATE.md",
    "docs/v1-migration-plan.md",
    "tools/validate-phase0.ps1"
)

Test-GitFact "current branch is codex/steadyagent-v1" @("branch", "--show-current") { param($output) ($output -join "").Trim() -eq "codex/steadyagent-v1" } "Wrong branch"
Test-GitFact "legacy tag exists" @("rev-parse", "-q", "--verify", "refs/tags/legacy-zsh-agent-rules-v0.1") { param($output) -not [string]::IsNullOrWhiteSpace(($output -join "")) } "Missing legacy tag"
Test-OnlyExpectedChangedFiles $phase0Files

Test-FileContains "PROJECT_STATE.md" @(
    "(?m)^# SteadyAgent",
    "(?m)^- Goal:",
    "(?m)^- Scope:",
    "(?m)^- Current phase:",
    "(?m)^- Validation:",
    "(?m)^- Review gate:",
    "(?m)^- Red check:",
    "(?m)^- Green check:",
    "(?m)^- Review score:"
)

Test-FileContains "docs/v1-migration-plan.md" @(
    "(?m)^# SteadyAgent v1 Migration Plan",
    "(?m)^## Product Positioning",
    "(?m)^## Bilingual Strategy",
    "(?m)^## Target Repository Structure",
    "(?m)^## TDD And Review Gates",
    "(?m)^## Phase Plan",
    "(?m)^### Phase 0 - Baseline And Migration Plan",
    "(?m)^### Phase 1 - README And Public Narrative",
    "(?m)^### Phase 2 - Public Templates And Rules",
    "(?m)^### Phase 3 - Tools And Hooks",
    "(?m)^### Phase 4 - Skill Packaging And Release Readiness",
    "(?m)^## Resume Narrative",
    "README[.]zh-CN[.]md",
    "architecture[.]zh-CN[.]md",
    "safety-model[.]zh-CN[.]md",
    "troubleshooting[.]zh-CN[.]md",
    "resume-case-study[.]zh-CN[.]md"
)

$slash = [string][char]47
$backslash = [string][char]92
$privatePathPattern = "(?i)(" + "C:" + [regex]::Escape($backslash + "Users" + $backslash) + "|" + [regex]::Escape($slash + "Users" + $slash) + "|E:" + [regex]::Escape($backslash) + "|D:" + [regex]::Escape($backslash) + ")"
$placeholderPattern = "(?i)(" + "TO" + "DO|TB" + "D|lorem " + "ipsum|your[-_ ]?name|replace " + "me)"
$secretPattern = "(?i)(api[_-]?key|access[_-]?token|secret[_-]?key|password\s*=|BEGIN (RSA|OPENSSH|PRIVATE) KEY)"

Test-NoPatternInFiles "phase0 files have no local absolute private paths" $phase0Files $privatePathPattern
Test-NoPatternInFiles "phase0 files have no obvious placeholders" $phase0Files $placeholderPattern
Test-NoPatternInFiles "phase0 files have no obvious secret material" $phase0Files $secretPattern

$failed = @($checks | Where-Object { -not $_.Passed })
foreach ($check in $checks) {
    $status = if ($check.Passed) { "PASS" } else { "FAIL" }
    Write-Host ("{0} {1} - {2}" -f $status, $check.Name, $check.Detail)
}

Write-Host ""
Write-Host ("RESULT pass={0} fail={1}" -f ($checks.Count - $failed.Count), $failed.Count)

if ($failed.Count -gt 0) {
    exit 1
}
