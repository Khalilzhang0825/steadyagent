[CmdletBinding()]
param(
    [string]$Root,
    [switch]$EnforceWorktreeScope
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
    return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
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

function Test-PowerShellSyntax {
    param([string]$RelativePath)

    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Check "$RelativePath parses as PowerShell" $false "Missing file"
        return
    }

    $tokens = $null
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    Add-Check "$RelativePath parses as PowerShell" ($errors.Count -eq 0) ($(if ($errors.Count -eq 0) { "OK" } else { ($errors | Select-Object -First 1).Message }))
}

function Invoke-CheckedCommand {
    param(
        [string]$Label,
        [scriptblock]$Command,
        [scriptblock]$Predicate,
        [string]$Detail
    )

    try {
        $output = & $Command
        $code = $LASTEXITCODE
        $passed = ($code -eq 0) -and (& $Predicate $output)
        Add-Check $Label $passed ($(if ($passed) { "OK" } else { $Detail + " Output: " + (($output | Out-String).Trim()) }))
    }
    catch {
        Add-Check $Label $false $_.Exception.Message
    }
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

    Add-Check "worktree changes are limited to Phase 3 files" ($unexpected.Count -eq 0) ($(if ($unexpected.Count -eq 0) { "OK" } else { "Unexpected: " + ($unexpected -join ", ") }))
}

$toolFiles = @(
    "tools/install.ps1",
    "tools/git-preflight.ps1",
    "tools/git-checkpoint.ps1",
    "tools/test-hooks.ps1",
    "tools/test-agent-hooks.ps1",
    "tools/validate-release-readiness.ps1",
    "tools/hooks/pre-commit.ps1"
)

$docFiles = @(
    "docs/tools.md",
    "docs/tools.zh-CN.md"
)

$phase3Files = @(
    "README.md",
    "README.zh-CN.md",
    "tools/validate-phase3.ps1"
) + $toolFiles + $docFiles

if ($EnforceWorktreeScope) {
    Test-OnlyExpectedChangedFiles $phase3Files
}

foreach ($file in $phase3Files) {
    Test-FileExists $file
}

foreach ($file in $toolFiles + @("tools/validate-phase3.ps1")) {
    Test-PowerShellSyntax $file
}

$readme = Read-Text "README.md"
$readmeZh = Read-Text "README.zh-CN.md"
$available = Get-SectionByLabel $readme "Available Today"
$availableZh = Get-SectionByLabel $readmeZh "Available Today"
$planned = Get-SectionByLabel $readme "Planned For v1"
$plannedZh = Get-SectionByLabel $readmeZh "Planned For v1"

Test-SectionContains "README.md Available Today lists public tools" $available "tools/"
Test-SectionContains "README.md Available Today lists dry-run installer" $available "dry-run installer"
Test-SectionContains "README.md Available Today lists hook smoke test" $available "hook smoke test"
Test-SectionContains "README.md Available Today lists release readiness" $available "release-readiness"
Test-SectionContains "README.md Available Today lists packaged skill" $available "steadyagent-workflow"
Test-Contains "README.md Quick Start points at Phase 3 validation" $readme ([regex]::Escape("powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-phase3.ps1"))
Test-Contains "README.md Quick Start points at release readiness validation" $readme ([regex]::Escape("powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-release-readiness.ps1"))
Test-SectionContains "README.zh-CN.md Available Today lists public tools" $availableZh "tools/"
Test-SectionContains "README.zh-CN.md Available Today lists dry-run installer" $availableZh "dry-run"
Test-Contains "README.zh-CN.md lists hook smoke test" $readmeZh "hook smoke test"
Test-SectionContains "README.zh-CN.md Available Today lists release readiness" $availableZh "release-readiness"
Test-SectionContains "README.zh-CN.md Available Today lists packaged skill" $availableZh "steadyagent-workflow"
Test-Contains "README.zh-CN.md Quick Start points at Phase 3 validation" $readmeZh ([regex]::Escape("powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-phase3.ps1"))
Test-Contains "README.zh-CN.md Quick Start points at release readiness validation" $readmeZh ([regex]::Escape("powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-release-readiness.ps1"))
Test-NoPattern "README.zh-CN.md does not deny the dry-run installer exists" $readmeZh "还没有安装器"

$install = Read-Text "tools/install.ps1"
Test-Contains "installer defaults to DryRun" $install "DryRun"
Test-Contains "installer supports Codex target" $install "Codex"
Test-Contains "installer supports Claude target" $install "Claude"
Test-Contains "installer requires explicit apply" $install "Apply"
Test-Contains "installer protects existing targets with Overwrite" $install "Overwrite"
Test-Contains "installer copies rules directory" $install "rules"
Test-Contains "installer copies templates" $install "templates"
Test-Contains "installer copies packaged skill" $install "skills/steadyagent-workflow"

$checkpoint = Read-Text "tools/git-checkpoint.ps1"
Test-Contains "checkpoint requires explicit Files" $checkpoint "Files"
Test-Contains "checkpoint supports DryRun" $checkpoint "DryRun"
Test-Contains "checkpoint rejects staged files outside Files" $checkpoint "Existing staged files are outside -Files"
Test-NoPattern "checkpoint does not stage every file by default" $checkpoint "git\s+add\s+(\.|-A|--all)"

$preflight = Read-Text "tools/git-preflight.ps1"
Test-Contains "preflight checks Git repository" $preflight "rev-parse"
Test-Contains "preflight checks .gitignore" $preflight "[.]gitignore"
Test-Contains "preflight checks large untracked files" $preflight "Large"

$hook = Read-Text "tools/hooks/pre-commit.ps1"
Test-Contains "pre-commit hook scans staged files" $hook "diff"
Test-Contains "pre-commit hook includes renamed staged files" $hook "ACMR"
Test-Contains "pre-commit hook reads staged file size" $hook "cat-file"
Test-Contains "pre-commit hook reads staged file content" $hook "show --textconv"
Test-Contains "pre-commit hook blocks secrets" $hook "secrets"
Test-Contains "pre-commit hook blocks large files" $hook "Large"

$toolsDoc = Read-Text "docs/tools.md"
$toolsDocZh = Read-Text "docs/tools.zh-CN.md"
foreach ($term in @(
    "Windows-first",
    "dry-run",
    "install.ps1",
    "git-preflight.ps1",
    "git-checkpoint.ps1",
    "test-hooks.ps1",
    "test-agent-hooks.ps1",
    "validate-release-readiness.ps1",
    "pre-commit.ps1",
    "Cross-platform"
)) {
    Test-Contains "docs/tools.md contains: $term" $toolsDoc ([regex]::Escape($term))
}
foreach ($term in @(
    "Windows-first",
    "dry-run",
    "install.ps1",
    "git-preflight.ps1",
    "git-checkpoint.ps1",
    "test-hooks.ps1",
    "test-agent-hooks.ps1",
    "validate-release-readiness.ps1",
    "pre-commit.ps1",
    "Cross-platform"
)) {
    Test-Contains "docs/tools.zh-CN.md contains: $term" $toolsDocZh ([regex]::Escape($term))
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("steadyagent-phase3-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    Push-Location $Root
    try {
        Invoke-CheckedCommand "install.ps1 dry-run reports plan without writing" {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\install.ps1" -HostTarget Codex -TargetRoot $tempRoot
        } {
            param($output)
            $text = ($output | Out-String)
            return ($text -match "DRY-RUN") -and ($text -match "WOULD copy") -and (-not (Test-Path -LiteralPath (Join-Path $tempRoot "AGENTS.md")))
        } "Dry-run did not report plan or wrote files"

        $existingTarget = Join-Path $tempRoot "existing-install"
        New-Item -ItemType Directory -Path $existingTarget | Out-Null
        Set-Content -LiteralPath (Join-Path $existingTarget "AGENTS.md") -Value "existing config"
        $existingOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\install.ps1" -HostTarget Codex -TargetRoot $existingTarget -Apply
        $existingCode = $LASTEXITCODE
        $existingText = Get-Content -LiteralPath (Join-Path $existingTarget "AGENTS.md") -Raw
        Add-Check "install.ps1 apply refuses existing target without Overwrite" ($existingCode -ne 0 -and ($existingOutput | Out-String) -match "Existing targets" -and $existingText -match "existing config") (($existingOutput | Out-String).Trim())

        $bothOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\install.ps1" -HostTarget Both -TargetRoot (Join-Path $tempRoot "both-target")
        $bothText = ($bothOutput | Out-String)
        Add-Check "install.ps1 Both with TargetRoot plans codex and claude subdirectories" (($LASTEXITCODE -eq 0) -and ($bothText -match "both-target.+codex") -and ($bothText -match "both-target.+claude")) $bothText

        Invoke-CheckedCommand "git-preflight.ps1 runs in repository" {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\git-preflight.ps1"
        } {
            param($output)
            $text = ($output | Out-String)
            return ($text -match "Repository") -and ($text -match "Git Identity")
        } "Preflight output missing expected sections"

        Invoke-CheckedCommand "git-checkpoint.ps1 dry-run avoids staging" {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\git-checkpoint.ps1" -DryRun -Message "test" -Files "README.md"
        } {
            param($output)
            $text = ($output | Out-String)
            return ($text -match "DRY-RUN") -and ($text -match "README.md")
        } "Checkpoint dry-run output missing expected plan"

        $checkpointRepo = Join-Path $tempRoot "checkpoint-repo"
        New-Item -ItemType Directory -Path $checkpointRepo | Out-Null
        Push-Location $checkpointRepo
        try {
            & git init | Out-Null
            & git config user.email "steadyagent@example.invalid"
            & git config user.name "SteadyAgent Test"
            Set-Content -LiteralPath "base.txt" -Value "base"
            & git add -- base.txt
            & git commit -m "base" | Out-Null
            Set-Content -LiteralPath "unrelated.txt" -Value "unrelated"
            & git add -- unrelated.txt
            Set-Content -LiteralPath "target.txt" -Value "target"
            $checkpointOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/git-checkpoint.ps1") -Message "test" -Files "target.txt"
            Add-Check "git-checkpoint refuses pre-staged unrelated files" ($LASTEXITCODE -ne 0 -and (($checkpointOutput | Out-String) -match "Existing staged files")) (($checkpointOutput | Out-String).Trim())
        }
        finally {
            Pop-Location
        }

        Invoke-CheckedCommand "test-hooks.ps1 smoke tests pass" {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\test-hooks.ps1"
        } {
            param($output)
            $text = ($output | Out-String)
            return ($text -match "RESULT pass=") -and ($text -match "fail=0")
        } "Hook smoke tests failed"
    }
    finally {
        Pop-Location
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

$slash = [string][char]47
$backslash = [string][char]92
$privatePathPattern = "(?i)(?<![A-Za-z])(" + "C:" + [regex]::Escape($backslash + "Users" + $backslash) + "|" + [regex]::Escape($slash + "Users" + $slash) + "|E:" + [regex]::Escape($backslash) + "|D:" + [regex]::Escape($backslash) + ")"
$placeholderPattern = "(?i)(" + "TO" + "DO|TB" + "D|lorem " + "ipsum|your[-_ ]?name|replace " + "me)"
$secretPattern = "(?i)(" + "api" + "[_-]?key|access" + "[_-]?token|secret" + "[_-]?key|pass" + "word\s*=|BEGIN (RSA|OPENSSH|PRIVATE) KEY)"
$legacySkillPattern = "zsh" + "-agent-workflow"
$legacyRepoPattern = "zsh" + "-agent-rules"

Test-NoPatternInFiles "Phase 3 files have no local absolute private paths" $phase3Files $privatePathPattern
Test-NoPatternInFiles "Phase 3 files have no obvious placeholders" $phase3Files $placeholderPattern
Test-NoPatternInFiles "Phase 3 files have no obvious secret material" $phase3Files $secretPattern
Test-NoPatternInFiles "Phase 3 primary README files do not use legacy skill name" @("README.md", "README.zh-CN.md") $legacySkillPattern
Test-NoPatternInFiles "Phase 3 public files do not use legacy repository name" $phase3Files $legacyRepoPattern

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
