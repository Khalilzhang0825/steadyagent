[CmdletBinding()]
param(
    [string]$Root,
    [switch]$AllowDirty
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

function Write-CheckResults {
    $failed = @($checks | Where-Object { -not $_.Passed })
    foreach ($check in $checks) {
        $status = if ($check.Passed) { "PASS" } else { "FAIL" }
        $detail = if ($check.Passed) { "OK" } else { $check.Detail }
        Write-Host ("{0} {1} - {2}" -f $status, $check.Name, $detail)
    }

    Write-Host ""
    Write-Host ("RESULT pass={0} fail={1}" -f ($checks.Count - $failed.Count), $failed.Count)
    return $failed.Count
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

function Test-PathMissing {
    param([string]$RelativePath)

    $path = Join-Path $Root $RelativePath
    Add-Check "$RelativePath is absent" (-not (Test-Path -LiteralPath $path)) "Legacy or obsolete path still exists"
}

function Test-ObsoletePhaseValidatorsAbsent {
    $toolsPath = Join-Path $Root "tools"
    $matches = @()
    if (Test-Path -LiteralPath $toolsPath -PathType Container) {
        $matches = @(Get-ChildItem -LiteralPath $toolsPath -File | Where-Object { $_.Name -match "^validate-phase[0-2][.]ps1$" } | ForEach-Object { "tools/" + $_.Name })
    }
    Add-Check "obsolete migration phase validators are absent" ($matches.Count -eq 0) ($(if ($matches.Count -eq 0) { "OK" } else { "Matched: " + ($matches -join ", ") }))
}

function Test-Contains {
    param(
        [string]$Label,
        [string]$Text,
        [string]$Pattern
    )

    Add-Check $Label (($null -ne $Text) -and ($Text -match $Pattern)) "Missing required content"
}

function New-UnicodeString {
    param([int[]]$CodePoints)

    return -join ($CodePoints | ForEach-Object { [char]$_ })
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

function Invoke-ExpectedFailureCommand {
    param(
        [string]$Label,
        [scriptblock]$Command,
        [scriptblock]$Predicate,
        [string]$Detail
    )

    try {
        $output = & $Command
        $code = $LASTEXITCODE
        $passed = ($code -ne 0) -and (& $Predicate $output)
        Add-Check $Label $passed ($(if ($passed) { "OK" } else { $Detail + " ExitCode: " + $code + " Output: " + (($output | Out-String).Trim()) }))
    }
    catch {
        Add-Check $Label $false $_.Exception.Message
    }
}

function Get-RepositoryStatusLines {
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
        return [PSCustomObject]@{
            Success = $false
            Lines = @()
        }
    }

    return [PSCustomObject]@{
        Success = $true
        Lines = @($status | Where-Object { $_ })
    }
}

function Test-RepositoryCleanOrAllowed {
    $statusResult = Get-RepositoryStatusLines
    if (-not $statusResult.Success) {
        return $false
    }

    $status = @($statusResult.Lines)
    if ($status.Count -eq 0) {
        Add-Check "repository is clean for release validation" $true "OK"
        return $true
    }

    if ($AllowDirty) {
        Add-Check "repository dirtiness is explicitly allowed for WIP validation" $true "OK"
        return $true
    }

    Add-Check "repository is clean for release validation" $false ("Dirty files: " + (($status | Select-Object -First 10) -join "; "))
    return $false
}

function Get-WorkspaceFiles {
    Push-Location $Root
    try {
        if ($AllowDirty) {
            $files = & git ls-files --cached --others --exclude-standard
        }
        else {
            $files = & git ls-files --cached
        }
        $code = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    if ($code -ne 0) {
        Add-Check "git ls-files is readable" $false "git ls-files failed"
        return @()
    }

    Add-Check "git ls-files is readable" $true "OK"
    return @($files | Where-Object { $_ })
}

function Copy-WorkspaceSnapshot {
    param(
        [string[]]$Files,
        [string]$Destination
    )

    foreach ($file in $Files) {
        $source = Join-Path $Root $file
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            continue
        }
        $target = Join-Path $Destination $file
        $parent = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

function Initialize-SnapshotRepository {
    param(
        [string]$SnapshotRoot,
        [string[]]$Files
    )

    Push-Location $SnapshotRoot
    try {
        & git init | Out-Null
        & git config user.email "steadyagent@example.invalid"
        & git config user.name "SteadyAgent Release Test"
        foreach ($file in $Files) {
            if (Test-Path -LiteralPath (Join-Path $SnapshotRoot $file) -PathType Leaf) {
                & git add -- $file
            }
        }
        & git commit -m "snapshot" | Out-Null
    }
    finally {
        Pop-Location
    }
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

function Test-MarkdownLinks {
    param([string[]]$MarkdownFiles)

    $broken = New-Object System.Collections.Generic.List[string]
    foreach ($relative in $MarkdownFiles) {
        $text = Read-Text $relative
        if ($null -eq $text) {
            continue
        }

        $base = Split-Path -Parent (Join-Path $Root $relative)
        if (-not $base) {
            $base = $Root
        }

        foreach ($match in [regex]::Matches($text, '\[[^\]]+\]\(([^)]+)\)')) {
            $target = $match.Groups[1].Value.Trim()
            if (-not $target -or $target.StartsWith("#")) {
                continue
            }
            if ($target -match '^(https?:|mailto:)') {
                continue
            }
            $targetPath = ($target -split '#')[0]
            if (-not $targetPath) {
                continue
            }
            $targetPath = [uri]::UnescapeDataString($targetPath)
            $resolved = Join-Path $base $targetPath
            if (-not (Test-Path -LiteralPath $resolved)) {
                $broken.Add("$relative -> $target") | Out-Null
            }
        }
    }

    Add-Check "local Markdown links resolve" ($broken.Count -eq 0) ($(if ($broken.Count -eq 0) { "OK" } else { $broken -join "; " }))
}

function Test-SteadyAgentTomlShape {
    param([string]$Text)

    if (-not $Text) { return $false }
    return ($Text -match "\[features\]") -and
        ($Text -match "\[hooks\]") -and
        ($Text -match "\[\[hooks[.]PreToolUse\]\]") -and
        ($Text -match "agent-hook-context[.]ps1") -and
        ($Text -match "agent-hook-prompt-reminder[.]ps1") -and
        ($Text -match "agent-hook-command-guard[.]ps1") -and
        ($Text -match "agent-hook-file-guard[.]ps1") -and
        ($Text -match "agent-hook-permission-guard[.]ps1") -and
        ($Text -match "agent-hook-posttool-audit[.]ps1") -and
        ($Text -match "agent-hook-precompact[.]ps1") -and
        (-not ($Text -match "STEADYAGENT_HOME"))
}

function Test-FreshCopyInstall {
    param([string[]]$Files)

    $snapshotRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("steadyagent-release-copy-" + [guid]::NewGuid().ToString("N"))
    $installRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("steadyagent-release-install-" + [guid]::NewGuid().ToString("N"))
    try {
        New-Item -ItemType Directory -Path $snapshotRoot | Out-Null
        Copy-WorkspaceSnapshot -Files $Files -Destination $snapshotRoot
        Initialize-SnapshotRepository -SnapshotRoot $snapshotRoot -Files $Files

        Push-Location $snapshotRoot
        try {
            Invoke-CheckedCommand "fresh copy phase3 validation passes" {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\validate-phase3.ps1"
            } {
                param($output)
                return (($output | Out-String) -match "RESULT pass=.*fail=0")
            } "Phase 3 validation failed in fresh copy"

            Invoke-CheckedCommand "fresh copy runtime validation passes" {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\validate-runtime-slice.ps1"
            } {
                param($output)
                return (($output | Out-String) -match "RESULT pass=.*fail=0")
            } "Runtime validation failed in fresh copy"

            Invoke-CheckedCommand "fresh copy installer apply works" {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\install.ps1" -HostTarget Both -TargetRoot $installRoot -Apply
            } {
                param($output)
                $text = ($output | Out-String)
                $codexRoot = Join-Path $installRoot "codex"
                $claudeRoot = Join-Path $installRoot "claude"
                $codexConfig = Join-Path $codexRoot "requirements.managed-hooks.example.toml"
                $claudeConfig = Join-Path $claudeRoot "settings.hooks.example.json"
                $codexSkill = Join-Path $codexRoot "skills/steadyagent-workflow/SKILL.md"
                $claudeSkill = Join-Path $claudeRoot "skills/steadyagent-workflow/SKILL.md"
                $codexDiagnose = Join-Path $codexRoot "tools/diagnose-install.ps1"
                $claudeDiagnose = Join-Path $claudeRoot "tools/diagnose-install.ps1"
                $codexEnabler = Join-Path $codexRoot "tools/enable-codex-hooks.ps1"
                $codexActivationGuide = Join-Path $codexRoot "docs/activation-guide.md"
                $claudeFeatureMap = Join-Path $claudeRoot "docs/feature-map.md"
                if (-not ((Test-Path -LiteralPath $codexConfig) -and
                    (Test-Path -LiteralPath $claudeConfig) -and
                    (Test-Path -LiteralPath $codexSkill) -and
                    (Test-Path -LiteralPath $claudeSkill) -and
                    (Test-Path -LiteralPath $codexDiagnose) -and
                    (Test-Path -LiteralPath $claudeDiagnose) -and
                    (Test-Path -LiteralPath $codexEnabler) -and
                    (Test-Path -LiteralPath $codexActivationGuide) -and
                    (Test-Path -LiteralPath $claudeFeatureMap))) {
                    return $false
                }
                $codexText = [System.IO.File]::ReadAllText($codexConfig, [System.Text.Encoding]::UTF8)
                $claudeText = [System.IO.File]::ReadAllText($claudeConfig, [System.Text.Encoding]::UTF8)
                $null = $claudeText | ConvertFrom-Json
                return ($text -match "APPLY SteadyAgent install") -and
                    (Test-SteadyAgentTomlShape -Text $codexText) -and
                    ($claudeText -match "agent-hook-context[.]ps1") -and
                    (-not ($claudeText -match "STEADYAGENT_HOME"))
            } "Installer did not produce usable rendered configs"

            Invoke-CheckedCommand "installed Codex hook smoke test passes" {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $installRoot "codex/tools/test-agent-hooks.ps1")
            } {
                param($output)
                return (($output | Out-String) -match "0 failed")
            } "Installed Codex runtime smoke failed"

            Invoke-CheckedCommand "installed Claude hook smoke test passes" {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $installRoot "claude/tools/test-agent-hooks.ps1")
            } {
                param($output)
                return (($output | Out-String) -match "0 failed")
            } "Installed Claude runtime smoke failed"

            Invoke-CheckedCommand "installed diagnosis passes with active config overrides" {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $installRoot "codex/tools/diagnose-install.ps1") -HostTarget Both -CodexRoot (Join-Path $installRoot "codex") -ClaudeRoot (Join-Path $installRoot "claude") -CodexManagedConfigPath (Join-Path $installRoot "codex/requirements.managed-hooks.example.toml") -ClaudeSettingsPath (Join-Path $installRoot "claude/settings.hooks.example.json") -RequireHooksActive
            } {
                param($output)
                return (($output | Out-String) -match "RESULT pass=.*fail=0")
            } "Installed diagnosis did not prove both hosts active"

            $badCodexConfig = Join-Path $installRoot "managed/bad-requirements.toml"
            $goodCodexConfigText = [System.IO.File]::ReadAllText((Join-Path $installRoot "codex/requirements.managed-hooks.example.toml"), [System.Text.Encoding]::UTF8)
            $badCodexConfigText = $goodCodexConfigText.Replace("agent-hook-file-guard.ps1", "agent-hook-file-guard.MISSING")
            $badCodexConfigParent = Split-Path -Parent $badCodexConfig
            if (-not (Test-Path -LiteralPath $badCodexConfigParent)) {
                New-Item -ItemType Directory -Path $badCodexConfigParent -Force | Out-Null
            }
            [System.IO.File]::WriteAllText($badCodexConfig, $badCodexConfigText, [System.Text.Encoding]::UTF8)

            Invoke-ExpectedFailureCommand "diagnosis fails when active Codex config misses file guard" {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $installRoot "codex/tools/diagnose-install.ps1") -HostTarget Codex -CodexRoot (Join-Path $installRoot "codex") -CodexManagedConfigPath $badCodexConfig -RequireHooksActive -SkipSmoke
            } {
                param($output)
                $text = ($output | Out-String)
                return ($text -match "FAIL Codex active managed hooks config registers file guard") -and
                    ($text -match "RESULT pass=.*fail=[1-9]")
            } "Diagnosis accepted an incomplete active Codex hook config"

            $managedTemp = Join-Path $installRoot "managed/requirements.toml"
            Invoke-CheckedCommand "Codex hook enabler dry-run previews target write" {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $installRoot "codex/tools/enable-codex-hooks.ps1") -ManagedConfigPath $managedTemp
            } {
                param($output)
                $text = ($output | Out-String)
                return ($text -match "DRY-RUN") -and ($text -match "WOULD create")
            } "Codex hook enabler dry-run did not preview activation"

            Invoke-CheckedCommand "Codex hook enabler apply writes temp managed config" {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $installRoot "codex/tools/enable-codex-hooks.ps1") -ManagedConfigPath $managedTemp -Apply
            } {
                param($output)
                if (-not (Test-Path -LiteralPath $managedTemp -PathType Leaf)) {
                    return $false
                }
                $text = [System.IO.File]::ReadAllText($managedTemp, [System.Text.Encoding]::UTF8)
                return (($output | Out-String) -match "WROTE") -and (Test-SteadyAgentTomlShape -Text $text)
            } "Codex hook enabler did not write usable temp config"

            $managedConflict = Join-Path $installRoot "managed/conflict-requirements.toml"
            $conflictBackupRoot = Join-Path $installRoot "managed/conflict-backups"
            [System.IO.File]::WriteAllText($managedConflict, "[other]`nvalue = true`n", [System.Text.Encoding]::UTF8)

            Invoke-ExpectedFailureCommand "Codex hook enabler refuses different target without ForceReplace" {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $installRoot "codex/tools/enable-codex-hooks.ps1") -ManagedConfigPath $managedConflict -BackupRoot $conflictBackupRoot -Apply
            } {
                param($output)
                return (($output | Out-String) -match "already exists and differs")
            } "Codex hook enabler replaced a different target without ForceReplace"

            Invoke-CheckedCommand "Codex hook enabler force-replaces and backs up existing target" {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $installRoot "codex/tools/enable-codex-hooks.ps1") -ManagedConfigPath $managedConflict -BackupRoot $conflictBackupRoot -Apply -ForceReplace
            } {
                param($output)
                if (-not (Test-Path -LiteralPath $managedConflict -PathType Leaf)) {
                    return $false
                }
                $backupFiles = @()
                if (Test-Path -LiteralPath $conflictBackupRoot -PathType Container) {
                    $backupFiles = @(Get-ChildItem -LiteralPath $conflictBackupRoot -File -Filter "*.bak")
                }
                $text = [System.IO.File]::ReadAllText($managedConflict, [System.Text.Encoding]::UTF8)
                return (($output | Out-String) -match "BACKUP") -and
                    ($backupFiles.Count -gt 0) -and
                    (Test-SteadyAgentTomlShape -Text $text)
            } "Codex hook enabler did not backup and force-replace a different target"

        }
        finally {
            Pop-Location
        }
    }
    finally {
        foreach ($path in @($snapshotRoot, $installRoot)) {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Recurse -Force
            }
        }
    }
}

$repositoryReady = Test-RepositoryCleanOrAllowed
if (-not $repositoryReady) {
    $failedCount = Write-CheckResults
    if ($failedCount -gt 0) {
        exit 1
    }
}
$workspaceFiles = Get-WorkspaceFiles

$requiredFiles = @(
    "AGENTS.md",
    "CLAUDE.md",
    ".gitattributes",
    "LICENSE",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "RELEASE_NOTES.md",
    ".github/ISSUE_TEMPLATE/bug_report.yml",
    ".github/ISSUE_TEMPLATE/feature_request.yml",
    ".github/pull_request_template.md",
    ".github/workflows/validate.yml",
    "docs/release-checklist.md",
    "docs/release-checklist.zh-CN.md",
    "docs/github-publication-runbook.md",
    "docs/github-publication-runbook.zh-CN.md",
    "docs/getting-started.md",
    "docs/getting-started.zh-CN.md",
    "docs/how-it-works.md",
    "docs/how-it-works.zh-CN.md",
    "docs/feature-map.md",
    "docs/feature-map.zh-CN.md",
    "docs/activation-guide.md",
    "docs/activation-guide.zh-CN.md",
    "docs/workflow-examples.md",
    "docs/workflow-examples.zh-CN.md",
    "docs/resume-case-study.md",
    "docs/resume-case-study.zh-CN.md",
    "skills/steadyagent-workflow/SKILL.md",
    "skills/steadyagent-workflow/agents/openai.yaml",
    "skills/steadyagent-workflow/references/claude-code-practices.md",
    "skills/steadyagent-workflow/references/karpathy-guardrails.md",
    "skills/steadyagent-workflow/references/mnilax-extensions.md",
    "skills/steadyagent-workflow/references/operating-principles.md",
    "skills/steadyagent-workflow/references/prompt-recipes.md",
    "tools/diagnose-install.ps1",
    "tools/enable-codex-hooks.ps1",
    "tools/validate-release-readiness.ps1"
)

foreach ($file in $requiredFiles) {
    Test-FileExists $file
}
$legacySkillPath = "skills/" + "zsh" + "-agent-workflow"
Test-PathMissing $legacySkillPath
Test-PathMissing "PROJECT_STATE.md"
Test-ObsoletePhaseValidatorsAbsent

foreach ($file in @(
    "tools/validate-release-readiness.ps1",
    "tools/validate-phase3.ps1",
    "tools/validate-runtime-slice.ps1",
    "tools/install.ps1",
    "tools/diagnose-install.ps1",
    "tools/enable-codex-hooks.ps1",
    "tools/test-agent-hooks.ps1"
)) {
    Test-PowerShellSyntax $file
}

$readme = Read-Text "README.md"
$readmeZh = Read-Text "README.zh-CN.md"
$quickStart = Get-SectionByLabel $readme "Quick Start"
$quickStartZh = Get-SectionByLabel $readmeZh "Quick Start"
$license = Read-Text "LICENSE"
$contributing = Read-Text "CONTRIBUTING.md"
$security = Read-Text "SECURITY.md"
$releaseNotes = Read-Text "RELEASE_NOTES.md"
$gitignore = Read-Text ".gitignore"
$releaseChecklist = Read-Text "docs/release-checklist.md"
$releaseChecklistZh = Read-Text "docs/release-checklist.zh-CN.md"
$publicationRunbook = Read-Text "docs/github-publication-runbook.md"
$publicationRunbookZh = Read-Text "docs/github-publication-runbook.zh-CN.md"
$publicationRunbookRelease = Get-SectionByLabel $publicationRunbook "Release"
$publicationRunbookReleaseZh = Get-SectionByLabel $publicationRunbookZh "Release"
$publicationRunbookPostPublish = Get-SectionByLabel $publicationRunbook "Post-Publish Checks"
$zhPostPublishLabel = New-UnicodeString @(0x53d1, 0x5e03, 0x540e, 0x68c0, 0x67e5)
$publicationRunbookPostPublishZh = Get-SectionByLabel $publicationRunbookZh $zhPostPublishLabel
$zhExplicitApproval = New-UnicodeString @(0x660e, 0x786e, 0x6279, 0x51c6)
$zhVersionNumber = New-UnicodeString @(0x7248, 0x672c, 0x53f7)
$zhPath = New-UnicodeString @(0x8def, 0x5f84)
$zhDualHostPath = New-UnicodeString @(0x53cc, 0x5bbf, 0x4e3b, 0x8def, 0x5f84)
$zhLearnFirst = New-UnicodeString @(0x5148, 0x7406, 0x89e3, 0x9879, 0x76ee)
$zhFirstPrompt = New-UnicodeString @(0x7b2c, 0x4e00, 0x6761, 0x63d0, 0x793a, 0x8bcd)
$zhFixBug = New-UnicodeString @(0x4fee)
$zhLongTaskResume = New-UnicodeString @(0x957f, 0x4efb, 0x52a1, 0x6062, 0x590d)
$zhReleaseCheck = New-UnicodeString @(0x53d1, 0x5e03, 0x68c0, 0x67e5)
$gettingStarted = Read-Text "docs/getting-started.md"
$gettingStartedZh = Read-Text "docs/getting-started.zh-CN.md"
$howItWorks = Read-Text "docs/how-it-works.md"
$howItWorksZh = Read-Text "docs/how-it-works.zh-CN.md"
$featureMap = Read-Text "docs/feature-map.md"
$featureMapZh = Read-Text "docs/feature-map.zh-CN.md"
$activationGuide = Read-Text "docs/activation-guide.md"
$activationGuideZh = Read-Text "docs/activation-guide.zh-CN.md"
$workflowExamples = Read-Text "docs/workflow-examples.md"
$workflowExamplesZh = Read-Text "docs/workflow-examples.zh-CN.md"
$resumeCaseStudy = Read-Text "docs/resume-case-study.md"
$resumeCaseStudyZh = Read-Text "docs/resume-case-study.zh-CN.md"
$workflow = Read-Text ".github/workflows/validate.yml"
$skill = Read-Text "skills/steadyagent-workflow/SKILL.md"
$toolsDoc = Read-Text "docs/tools.md"
$toolsDocZh = Read-Text "docs/tools.zh-CN.md"
$install = Read-Text "tools/install.ps1"
$diagnoseInstall = Read-Text "tools/diagnose-install.ps1"
$enableCodexHooks = Read-Text "tools/enable-codex-hooks.ps1"
$releaseReadiness = Read-Text "tools/validate-release-readiness.ps1"

Test-Contains "README.md Quick Start uses release-readiness gate" $quickStart ([regex]::Escape("powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-release-readiness.ps1"))
Test-Contains "README.zh-CN.md Quick Start uses release-readiness gate" $quickStartZh ([regex]::Escape("powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-release-readiness.ps1"))
Test-Contains "README.md Quick Start includes installer dry-run" $quickStart "install[.]ps1.+-HostTarget Both"
Test-Contains "README.zh-CN.md Quick Start includes installer dry-run" $quickStartZh "install[.]ps1.+-HostTarget Both"
Test-Contains "README.md Quick Start includes Codex dry-run" $quickStart "install[.]ps1.+-HostTarget Codex"
Test-Contains "README.zh-CN.md Quick Start includes Codex dry-run" $quickStartZh "install[.]ps1.+-HostTarget Codex"
Test-Contains "README.md Quick Start includes Claude dry-run" $quickStart "install[.]ps1.+-HostTarget Claude"
Test-Contains "README.zh-CN.md Quick Start includes Claude dry-run" $quickStartZh "install[.]ps1.+-HostTarget Claude"
Test-Contains "README.md links beginner onboarding" $readme "docs/getting-started[.]md"
Test-Contains "README.zh-CN.md links beginner onboarding" $readmeZh "docs/getting-started[.]zh-CN[.]md"
Test-Contains "README.md links how-it-works" $readme "docs/how-it-works[.]md"
Test-Contains "README.zh-CN.md links how-it-works" $readmeZh "docs/how-it-works[.]zh-CN[.]md"
Test-Contains "README.md links feature map" $readme "docs/feature-map[.]md"
Test-Contains "README.zh-CN.md links feature map" $readmeZh "docs/feature-map[.]zh-CN[.]md"
Test-Contains "README.md links activation guide" $readme "docs/activation-guide[.]md"
Test-Contains "README.zh-CN.md links activation guide" $readmeZh "docs/activation-guide[.]zh-CN[.]md"
Test-Contains "README.md links workflow examples" $readme "docs/workflow-examples[.]md"
Test-Contains "README.zh-CN.md links workflow examples" $readmeZh "docs/workflow-examples[.]zh-CN[.]md"
$notPackagedText = "not packaged as " + "an installer yet"
$futureFreshCloneText = "will add " + "fresh-clone instructions"
$missingReleasePackagePattern = $notPackagedText + "|" + $futureFreshCloneText
$missingReleasePackagePatternZh = $notPackagedText + "|" + "会加入 " + "fresh-clone"
Test-NoPattern "README.md no longer says release package is missing" $readme $missingReleasePackagePattern
Test-NoPattern "README.zh-CN.md no longer says release package is missing" $readmeZh $missingReleasePackagePatternZh
Test-Contains "README.md License section names MIT" $readme "MIT"
Test-Contains "README.zh-CN.md License section names MIT" $readmeZh "MIT"

Test-Contains "LICENSE uses MIT" $license "MIT License"
Test-Contains "CONTRIBUTING explains validation before PRs" $contributing "validate-release-readiness[.]ps1"
Test-Contains "SECURITY explains private reporting boundary" $security "security"
Test-Contains "RELEASE_NOTES contains exact v1.0.0 release heading" $releaseNotes "(?m)^##\s+v1[.]0[.]0\s*$"
Test-Contains ".gitignore excludes node_modules" $gitignore "node_modules/"
Test-Contains ".gitignore excludes .venv" $gitignore "[.]venv/"
Test-Contains ".gitignore excludes dist" $gitignore "dist/"
Test-Contains ".gitignore excludes build" $gitignore "build/"
Test-Contains ".gitignore excludes local agent state" $gitignore "(?m)^[.]agent/"
Test-Contains "release checklist includes fresh clone validation" $releaseChecklist "fresh-clone"
Test-Contains "release checklist includes no-push boundary" $releaseChecklist "Do not push"
Test-Contains "Chinese release checklist includes fresh clone validation" $releaseChecklistZh "fresh-clone"
Test-Contains "publication runbook gates remote push approval" $publicationRunbook "Only run after explicit maintainer approval"
Test-Contains "publication runbook gates tag and release approval" $publicationRunbookRelease "explicit maintainer approval.+tag.+release"
Test-Contains "publication runbook confirms tag target commit" $publicationRunbookRelease "tag name.+target commit"
Test-Contains "publication runbook includes repository metadata" $publicationRunbook "Repository Metadata"
Test-Contains "publication runbook records GitHub Actions evidence" $publicationRunbookPostPublish "GitHub Actions run URL"
Test-Contains "publication runbook records metadata evidence" $publicationRunbookPostPublish "repository metadata update notes"
Test-Contains "publication runbook documents stale branch cleanup" $publicationRunbook "Delete stale remote branches"
Test-Contains "publication runbook documents release replacement" $publicationRunbook "Delete or replace the existing GitHub release"
Test-Contains "publication runbook documents fresh clone ref checks" $publicationRunbook "git branch -r"
Test-Contains "publication runbook documents clean history log checks" $publicationRunbook "git log --all"
Test-Contains "Chinese publication runbook gates remote push approval" $publicationRunbookZh (([regex]::Escape($zhExplicitApproval)) + ".+explicit maintainer approval")
Test-Contains "Chinese publication runbook gates tag and release approval" $publicationRunbookReleaseZh (([regex]::Escape($zhExplicitApproval)) + ".+tag/release")
Test-Contains "Chinese publication runbook confirms release version and commit" $publicationRunbookReleaseZh (([regex]::Escape($zhVersionNumber)) + ".+commit")
Test-Contains "Chinese publication runbook includes repository metadata" $publicationRunbookZh "Repository Metadata"
Test-Contains "Chinese publication runbook records GitHub Actions evidence" $publicationRunbookPostPublishZh "GitHub Actions run URL"
Test-Contains "Chinese publication runbook records metadata evidence" $publicationRunbookPostPublishZh "repository metadata update notes"
Test-Contains "Chinese publication runbook documents stale branch cleanup" $publicationRunbookZh "stale remote branches"
Test-Contains "Chinese publication runbook documents release replacement" $publicationRunbookZh "GitHub release"
Test-Contains "Chinese publication runbook documents fresh clone ref checks" $publicationRunbookZh "git branch -r"
Test-Contains "Chinese publication runbook documents clean history log checks" $publicationRunbookZh "git log --all"
Test-Contains "getting-started explains new Codex path" $gettingStarted "New to Codex Path"
Test-Contains "getting-started explains Claude Code path" $gettingStarted "Claude Code Path"
Test-Contains "getting-started includes dry-run behavior" $gettingStarted "DRY-RUN"
Test-Contains "getting-started includes Codex apply command" $gettingStarted "install[.]ps1.+-HostTarget Codex.+-Apply"
Test-Contains "getting-started includes hook smoke test" $gettingStarted "test-agent-hooks[.]ps1"
Test-Contains "getting-started includes Codex enabler" $gettingStarted "enable-codex-hooks[.]ps1"
Test-Contains "getting-started includes install diagnosis" $gettingStarted "diagnose-install[.]ps1"
Test-Contains "getting-started includes first prompt" $gettingStarted "first prompt"
Test-Contains "Chinese getting-started includes Codex path" $gettingStartedZh "Codex"
Test-Contains "Chinese getting-started includes apply command" $gettingStartedZh "install[.]ps1.+-HostTarget Codex.+-Apply"
Test-Contains "Chinese getting-started includes Codex enabler" $gettingStartedZh "enable-codex-hooks[.]ps1"
Test-Contains "Chinese getting-started includes install diagnosis" $gettingStartedZh "diagnose-install[.]ps1"
Test-Contains "Chinese getting-started includes Claude Code path" $gettingStartedZh ("Claude Code\s+" + [regex]::Escape($zhPath))
Test-Contains "Chinese getting-started includes dual host path" $gettingStartedZh ([regex]::Escape($zhDualHostPath))
Test-Contains "Chinese getting-started includes learn-first path" $gettingStartedZh ([regex]::Escape($zhLearnFirst))
Test-Contains "Chinese getting-started includes Claude apply command" $gettingStartedZh "install[.]ps1.+-HostTarget Claude.+-Apply"
Test-Contains "Chinese getting-started includes both-host preview" $gettingStartedZh "install[.]ps1.+-HostTarget Both.+-TargetRoot"
Test-Contains "Chinese getting-started includes hook smoke test" $gettingStartedZh "test-agent-hooks[.]ps1"
Test-Contains "Chinese getting-started includes first prompt" $gettingStartedZh ([regex]::Escape($zhFirstPrompt))
Test-Contains "how-it-works covers Instructions" $howItWorks "Instructions"
Test-Contains "how-it-works covers Rules" $howItWorks "Rules"
Test-Contains "how-it-works covers Skills" $howItWorks "Skills"
Test-Contains "how-it-works covers Tools" $howItWorks "Tools"
Test-Contains "how-it-works covers Hooks" $howItWorks "Hooks"
Test-Contains "how-it-works covers Validation" $howItWorks "Validation"
Test-Contains "how-it-works names feature map" $howItWorks "feature-map"
Test-Contains "how-it-works names activation guide" $howItWorks "activation-guide"
Test-Contains "how-it-works explains Codex and Claude Code" $howItWorks "Codex.+Claude Code"
Test-Contains "Chinese how-it-works explains Codex and Claude Code" $howItWorksZh "Codex.+Claude Code"
Test-Contains "feature map maps implementation files" $featureMap "Implementation files"
Test-Contains "feature map maps activation helper" $featureMap "enable-codex-hooks[.]ps1"
Test-Contains "feature map explains host activation" $featureMap "require host activation"
Test-Contains "Chinese feature map maps implementation files" $featureMapZh ([regex]::Escape((New-UnicodeString @(0x5b9e, 0x73b0, 0x6587, 0x4ef6))))
Test-Contains "Chinese feature map maps activation helper" $featureMapZh "enable-codex-hooks[.]ps1"
Test-Contains "activation guide separates install and activation" $activationGuide "Installation and activation are different"
Test-Contains "activation guide includes diagnosis" $activationGuide "diagnose-install[.]ps1"
Test-Contains "activation guide includes functional probes" $activationGuide "Functional Probe"
Test-Contains "Chinese activation guide includes diagnosis" $activationGuideZh "diagnose-install[.]ps1"
Test-Contains "Chinese activation guide includes functional probes" $activationGuideZh ([regex]::Escape((New-UnicodeString @(0x89e6, 0x53d1, 0x529f, 0x80fd))))
Test-Contains "workflow examples cover bug fix" $workflowExamples "Bug Fix"
Test-Contains "workflow examples cover feature work" $workflowExamples "Feature Work"
Test-Contains "workflow examples cover code review" $workflowExamples "Code Review"
Test-Contains "workflow examples cover long task resume" $workflowExamples "Long Task Resume"
Test-Contains "workflow examples cover release check" $workflowExamples "validate-release-readiness[.]ps1"
Test-Contains "Chinese workflow examples cover bug fix" $workflowExamplesZh ([regex]::Escape($zhFixBug) + "\s+bug")
Test-Contains "Chinese workflow examples cover review" $workflowExamplesZh "review"
Test-Contains "Chinese workflow examples cover feature" $workflowExamplesZh "feature"
Test-Contains "Chinese workflow examples cover long task resume" $workflowExamplesZh ([regex]::Escape($zhLongTaskResume))
Test-Contains "Chinese workflow examples cover release check" $workflowExamplesZh ([regex]::Escape($zhReleaseCheck))
Test-Contains "Chinese workflow examples include release gate command" $workflowExamplesZh "validate-release-readiness[.]ps1"
Test-Contains "resume case study explains evidence" $resumeCaseStudy "Evidence"
Test-Contains "Chinese resume case study explains evidence" $resumeCaseStudyZh "release-readiness"
Test-Contains "GitHub workflow runs on Windows" $workflow "windows-latest"
Test-Contains "GitHub workflow runs release gate" $workflow "validate-release-readiness[.]ps1"
Test-Contains "tools doc lists release gate" $toolsDoc "validate-release-readiness[.]ps1"
Test-Contains "Chinese tools doc lists release gate" $toolsDocZh "validate-release-readiness[.]ps1"
Test-Contains "tools doc lists diagnose install" $toolsDoc "diagnose-install[.]ps1"
Test-Contains "tools doc lists Codex enabler" $toolsDoc "enable-codex-hooks[.]ps1"
Test-Contains "Chinese tools doc lists diagnose install" $toolsDocZh "diagnose-install[.]ps1"
Test-Contains "Chinese tools doc lists Codex enabler" $toolsDocZh "enable-codex-hooks[.]ps1"
Test-Contains "installer copies diagnosis script" $install "diagnose-install[.]ps1"
Test-Contains "installer copies Codex enabler" $install "enable-codex-hooks[.]ps1"
Test-Contains "diagnose install can require hooks active" $diagnoseInstall "RequireHooksActive"
Test-Contains "diagnose install checks Codex managed config" $diagnoseInstall "CodexManagedConfigPath"
Test-Contains "diagnose install checks Claude settings" $diagnoseInstall "ClaudeSettingsPath"
Test-Contains "Codex enabler is dry-run by default" $enableCodexHooks "DRY-RUN SteadyAgent Codex hook activation"
Test-Contains "Codex enabler backs up existing target" $enableCodexHooks "BACKUP"
Test-Contains "Codex enabler checks admin for ProgramData" $enableCodexHooks "Administrator"
Test-Contains "release gate supports WIP validation opt-in" $releaseReadiness "AllowDirty"
Test-Contains "skill is renamed to steadyagent-workflow" $skill "name:\s+steadyagent-workflow"
Test-NoPattern "skill no longer uses legacy name" $skill ("zsh" + "-agent")

$markdownFiles = @($workspaceFiles | Where-Object { $_ -match "[.]md$" })
Test-MarkdownLinks $markdownFiles

$releaseSurface = @(
    "AGENTS.md",
    "CLAUDE.md",
    "README.md",
    "README.zh-CN.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "RELEASE_NOTES.md",
    "docs/tools.md",
    "docs/tools.zh-CN.md",
    "docs/getting-started.md",
    "docs/getting-started.zh-CN.md",
    "docs/how-it-works.md",
    "docs/how-it-works.zh-CN.md",
    "docs/feature-map.md",
    "docs/feature-map.zh-CN.md",
    "docs/activation-guide.md",
    "docs/activation-guide.zh-CN.md",
    "docs/workflow-examples.md",
    "docs/workflow-examples.zh-CN.md",
    "docs/hook-runtime.md",
    "docs/hook-runtime.zh-CN.md",
    "docs/release-checklist.md",
    "docs/release-checklist.zh-CN.md",
    "docs/github-publication-runbook.md",
    "docs/github-publication-runbook.zh-CN.md",
    "docs/resume-case-study.md",
    "docs/resume-case-study.zh-CN.md",
    "templates/codex/AGENTS.md",
    "templates/codex/requirements.managed-hooks.example.toml",
    "templates/claude/CLAUDE.md",
    "templates/claude/settings.hooks.example.json",
    "skills/steadyagent-workflow/SKILL.md"
)

$primaryNamingSurface = @(
    "AGENTS.md",
    "CLAUDE.md",
    "README.md",
    "README.zh-CN.md",
    "templates/codex/AGENTS.md",
    "templates/codex/requirements.managed-hooks.example.toml",
    "templates/claude/CLAUDE.md",
    "templates/claude/settings.hooks.example.json",
    "skills/steadyagent-workflow/SKILL.md"
)

$slash = [string][char]47
$backslash = [string][char]92
$privatePathPattern = "(?i)(?<![A-Za-z])(" + "C:" + [regex]::Escape($backslash + "Users" + $backslash) + "|" + [regex]::Escape($slash + "Users" + $slash) + "|E:" + [regex]::Escape($backslash) + "|D:" + [regex]::Escape($backslash) + ")"
$secretPattern = "(?i)(" + "api" + "[_-]?key|access" + "[_-]?token|secret" + "[_-]?key|pass" + "word\s*=|BEGIN (RSA|OPENSSH|PRIVATE) KEY)"
$legacyPattern = "(?i)" + "zsh" + "-agent"
$legacyRepoPattern = "(?i)" + "zsh" + "-agent-rules"
$upperRc = ([string][char]82) + ([string][char]67)
$lowerRc = ([string][char]114) + ([string][char]99)
$preReleasePattern = "(?i)" + "release" + "[- ]" + "candidate|v1[.]0[.]0\s+" + "release" + "\s+" + "candidate|\b" + $lowerRc + "[.]1\b|\b" + $upperRc + "\b"
$problemLabel = New-UnicodeString @(0x3010, 0x95EE, 0x9898, 0x63CF, 0x8FF0, 0x3011)
$fixLabel = New-UnicodeString @(0x3010, 0x4FEE, 0x590D, 0x601D, 0x8DEF, 0x3011)
$reproLabel = New-UnicodeString @(0x3010, 0x590D, 0x73B0, 0x8DEF, 0x5F84, 0x3011)
$internalCheckpointPattern = [regex]::Escape($problemLabel) + "|" + [regex]::Escape($fixLabel) + "|" + [regex]::Escape($reproLabel)
$trackedAgentState = @($workspaceFiles | Where-Object { $_ -match "^[.]agent/" })
$workspaceScanFiles = @($workspaceFiles | Where-Object { $_ -ne "LICENSE" })

Add-Check ".agent local state is not tracked" ($trackedAgentState.Count -eq 0) ($(if ($trackedAgentState.Count -eq 0) { "OK" } else { "Tracked: " + ($trackedAgentState -join ", ") }))
Test-NoPatternInFiles "tracked workspace has no local absolute private paths" $workspaceScanFiles $privatePathPattern
Test-NoPatternInFiles "tracked workspace has no obvious secret material" $workspaceScanFiles $secretPattern
Test-NoPatternInFiles "tracked workspace has no private checkpoint labels" $workspaceScanFiles $internalCheckpointPattern
Test-NoPatternInFiles "tracked workspace has no legacy repository name" $workspaceScanFiles $legacyRepoPattern
Test-NoPatternInFiles "release surface has no local absolute private paths" $releaseSurface $privatePathPattern
Test-NoPatternInFiles "release surface has no obvious secret material" $releaseSurface $secretPattern
Test-NoPatternInFiles "release surface has no prerelease wording" $releaseSurface $preReleasePattern
Test-NoPatternInFiles "release surface has no private checkpoint labels" $releaseSurface $internalCheckpointPattern
Test-NoPatternInFiles "primary release surface has no legacy product naming" $primaryNamingSurface $legacyPattern

Test-FreshCopyInstall $workspaceFiles

$failedCount = Write-CheckResults
if ($failedCount -gt 0) {
    exit 1
}
