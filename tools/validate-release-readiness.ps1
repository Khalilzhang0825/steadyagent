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
                if (-not ((Test-Path -LiteralPath $codexConfig) -and
                    (Test-Path -LiteralPath $claudeConfig) -and
                    (Test-Path -LiteralPath $codexSkill) -and
                    (Test-Path -LiteralPath $claudeSkill))) {
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

            $legacyKeepRoot = Join-Path $installRoot "legacy-keep"
            $legacyKeepPath = Join-Path $legacyKeepRoot "skills/zsh-agent-workflow"
            New-Item -ItemType Directory -Path $legacyKeepPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $legacyKeepPath "SKILL.md") -Value "legacy"
            Invoke-CheckedCommand "installer warns about legacy skill without removal" {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\install.ps1" -HostTarget Codex -TargetRoot $legacyKeepRoot -Apply
            } {
                param($output)
                $text = ($output | Out-String)
                return ($text -match "LEGACY skill detected") -and
                    (Test-Path -LiteralPath (Join-Path $legacyKeepRoot "skills/zsh-agent-workflow/SKILL.md")) -and
                    (Test-Path -LiteralPath (Join-Path $legacyKeepRoot "skills/steadyagent-workflow/SKILL.md"))
            } "Installer did not warn while preserving legacy skill"

            $legacyRemoveRoot = Join-Path $installRoot "legacy-remove"
            $legacyRemovePath = Join-Path $legacyRemoveRoot "skills/zsh-agent-workflow"
            New-Item -ItemType Directory -Path $legacyRemovePath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $legacyRemovePath "SKILL.md") -Value "legacy"
            Invoke-CheckedCommand "installer removes legacy skill when requested" {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\install.ps1" -HostTarget Codex -TargetRoot $legacyRemoveRoot -Apply -RemoveLegacySkill
            } {
                param($output)
                $text = ($output | Out-String)
                return ($text -match "REMOVED legacy skill") -and
                    (-not (Test-Path -LiteralPath (Join-Path $legacyRemoveRoot "skills/zsh-agent-workflow"))) -and
                    (Test-Path -LiteralPath (Join-Path $legacyRemoveRoot "skills/steadyagent-workflow/SKILL.md"))
            } "Installer did not remove legacy skill when requested"
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
    "docs/resume-case-study.md",
    "docs/resume-case-study.zh-CN.md",
    "skills/steadyagent-workflow/SKILL.md",
    "skills/steadyagent-workflow/agents/openai.yaml",
    "skills/steadyagent-workflow/references/claude-code-practices.md",
    "skills/steadyagent-workflow/references/karpathy-guardrails.md",
    "skills/steadyagent-workflow/references/mnilax-extensions.md",
    "skills/steadyagent-workflow/references/operating-principles.md",
    "skills/steadyagent-workflow/references/prompt-recipes.md",
    "tools/validate-release-readiness.ps1"
)

foreach ($file in $requiredFiles) {
    Test-FileExists $file
}
$legacySkillPath = "skills/" + "zsh" + "-agent-workflow"
Test-PathMissing $legacySkillPath

foreach ($file in @(
    "tools/validate-release-readiness.ps1",
    "tools/validate-phase3.ps1",
    "tools/validate-runtime-slice.ps1",
    "tools/install.ps1",
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
$resumeCaseStudy = Read-Text "docs/resume-case-study.md"
$resumeCaseStudyZh = Read-Text "docs/resume-case-study.zh-CN.md"
$workflow = Read-Text ".github/workflows/validate.yml"
$skill = Read-Text "skills/steadyagent-workflow/SKILL.md"
$toolsDoc = Read-Text "docs/tools.md"
$toolsDocZh = Read-Text "docs/tools.zh-CN.md"
$install = Read-Text "tools/install.ps1"
$releaseReadiness = Read-Text "tools/validate-release-readiness.ps1"

Test-Contains "README.md Quick Start uses release-readiness gate" $quickStart ([regex]::Escape("powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-release-readiness.ps1"))
Test-Contains "README.zh-CN.md Quick Start uses release-readiness gate" $quickStartZh ([regex]::Escape("powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-release-readiness.ps1"))
Test-Contains "README.md Quick Start includes installer dry-run" $quickStart "install[.]ps1.+-HostTarget Both"
Test-Contains "README.zh-CN.md Quick Start includes installer dry-run" $quickStartZh "install[.]ps1.+-HostTarget Both"
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
Test-Contains "release checklist includes fresh clone validation" $releaseChecklist "fresh-clone"
Test-Contains "release checklist includes no-push boundary" $releaseChecklist "Do not push"
Test-Contains "Chinese release checklist includes fresh clone validation" $releaseChecklistZh "fresh-clone"
Test-Contains "publication runbook gates remote push approval" $publicationRunbook "Only run after explicit maintainer approval"
Test-Contains "publication runbook gates tag and release approval" $publicationRunbookRelease "explicit maintainer approval.+tag.+release"
Test-Contains "publication runbook confirms tag target commit" $publicationRunbookRelease "tag name.+target commit"
Test-Contains "publication runbook includes repository metadata" $publicationRunbook "Repository Metadata"
Test-Contains "publication runbook records GitHub Actions evidence" $publicationRunbookPostPublish "GitHub Actions run URL"
Test-Contains "publication runbook records metadata evidence" $publicationRunbookPostPublish "repository metadata update notes"
Test-Contains "Chinese publication runbook gates remote push approval" $publicationRunbookZh (([regex]::Escape($zhExplicitApproval)) + ".+explicit maintainer approval")
Test-Contains "Chinese publication runbook gates tag and release approval" $publicationRunbookReleaseZh (([regex]::Escape($zhExplicitApproval)) + ".+tag/release")
Test-Contains "Chinese publication runbook confirms release version and commit" $publicationRunbookReleaseZh (([regex]::Escape($zhVersionNumber)) + ".+commit")
Test-Contains "Chinese publication runbook includes repository metadata" $publicationRunbookZh "Repository Metadata"
Test-Contains "Chinese publication runbook records GitHub Actions evidence" $publicationRunbookPostPublishZh "GitHub Actions run URL"
Test-Contains "Chinese publication runbook records metadata evidence" $publicationRunbookPostPublishZh "repository metadata update notes"
Test-Contains "resume case study explains evidence" $resumeCaseStudy "Evidence"
Test-Contains "Chinese resume case study explains evidence" $resumeCaseStudyZh "release-readiness"
Test-Contains "GitHub workflow runs on Windows" $workflow "windows-latest"
Test-Contains "GitHub workflow runs release gate" $workflow "validate-release-readiness[.]ps1"
Test-Contains "tools doc lists release gate" $toolsDoc "validate-release-readiness[.]ps1"
Test-Contains "Chinese tools doc lists release gate" $toolsDocZh "validate-release-readiness[.]ps1"
Test-Contains "installer supports legacy skill cleanup" $install "RemoveLegacySkill"
Test-Contains "release gate supports WIP validation opt-in" $releaseReadiness "AllowDirty"
Test-Contains "skill is renamed to steadyagent-workflow" $skill "name:\s+steadyagent-workflow"
Test-NoPattern "skill no longer uses legacy name" $skill ("zsh" + "-agent")

$markdownFiles = @($workspaceFiles | Where-Object { $_ -match "[.]md$" })
Test-MarkdownLinks $markdownFiles

$releaseSurface = @(
    "README.md",
    "README.zh-CN.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "RELEASE_NOTES.md",
    "docs/tools.md",
    "docs/tools.zh-CN.md",
    "docs/hook-runtime.md",
    "docs/hook-runtime.zh-CN.md",
    "docs/release-checklist.md",
    "docs/release-checklist.zh-CN.md",
    "docs/github-publication-runbook.md",
    "docs/github-publication-runbook.zh-CN.md",
    "docs/release-plan.md",
    "docs/v1-migration-plan.md",
    "docs/resume-case-study.md",
    "docs/resume-case-study.zh-CN.md",
    "templates/codex/AGENTS.md",
    "templates/codex/requirements.managed-hooks.example.toml",
    "templates/claude/CLAUDE.md",
    "templates/claude/settings.hooks.example.json",
    "skills/steadyagent-workflow/SKILL.md"
)

$primaryNamingSurface = @(
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
$upperRc = ([string][char]82) + ([string][char]67)
$lowerRc = ([string][char]114) + ([string][char]99)
$preReleasePattern = "(?i)" + "release" + "[- ]" + "candidate|v1[.]0[.]0\s+" + "release" + "\s+" + "candidate|\b" + $lowerRc + "[.]1\b|\b" + $upperRc + "\b"

Test-NoPatternInFiles "release surface has no local absolute private paths" $releaseSurface $privatePathPattern
Test-NoPatternInFiles "release surface has no obvious secret material" $releaseSurface $secretPattern
Test-NoPatternInFiles "release surface has no prerelease wording" $releaseSurface $preReleasePattern
Test-NoPatternInFiles "primary release surface has no legacy product naming" $primaryNamingSurface $legacyPattern

Test-FreshCopyInstall $workspaceFiles

$failedCount = Write-CheckResults
if ($failedCount -gt 0) {
    exit 1
}
