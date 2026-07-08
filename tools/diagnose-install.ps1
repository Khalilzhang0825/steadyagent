[CmdletBinding()]
param(
    [ValidateSet("Codex", "Claude", "Both")]
    [string]$HostTarget = "Both",

    [string]$CodexRoot,

    [string]$ClaudeRoot,

    [string]$CodexManagedConfigPath,

    [string]$ClaudeSettingsPath,

    [switch]$RequireHooksActive,

    [switch]$SkipSmoke
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

if (-not $CodexRoot) {
    $CodexRoot = Join-Path $HOME ".codex"
}
if (-not $ClaudeRoot) {
    $ClaudeRoot = Join-Path $HOME ".claude"
}
if (-not $CodexManagedConfigPath) {
    $programData = $env:ProgramData
    if (-not $programData) {
        $systemDrive = $env:SystemDrive
        if (-not $systemDrive) { $systemDrive = "C:" }
        $programData = Join-Path $systemDrive "ProgramData"
    }
    $CodexManagedConfigPath = Join-Path $programData "OpenAI/Codex/requirements.toml"
}
if (-not $ClaudeSettingsPath) {
    $ClaudeSettingsPath = Join-Path $ClaudeRoot "settings.json"
}

$script:results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [ValidateSet("PASS", "WARN", "FAIL")]
        [string]$Status,
        [string]$Name,
        [string]$Detail
    )

    $script:results.Add([PSCustomObject]@{
        Status = $Status
        Name = $Name
        Detail = $Detail
    }) | Out-Null
}

function Add-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Detail,
        [ValidateSet("WARN", "FAIL")]
        [string]$Severity = "FAIL"
    )

    if ($Passed) {
        Add-Result "PASS" $Name "OK"
    }
    else {
        Add-Result $Severity $Name $Detail
    }
}

function Read-TextFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Test-FilePresent {
    param(
        [string]$Path,
        [string]$Name,
        [ValidateSet("WARN", "FAIL")]
        [string]$Severity = "FAIL"
    )

    Add-Check $Name (Test-Path -LiteralPath $Path -PathType Leaf) ("Missing file: " + $Path) $Severity
}

function Test-DirectoryPresent {
    param(
        [string]$Path,
        [string]$Name,
        [ValidateSet("WARN", "FAIL")]
        [string]$Severity = "FAIL"
    )

    Add-Check $Name (Test-Path -LiteralPath $Path -PathType Container) ("Missing directory: " + $Path) $Severity
}

function Test-TextPattern {
    param(
        [string]$Name,
        [string]$Text,
        [string]$Pattern,
        [string]$Detail,
        [ValidateSet("WARN", "FAIL")]
        [string]$Severity = "FAIL"
    )

    Add-Check $Name (($null -ne $Text) -and ($Text -match $Pattern)) $Detail $Severity
}

function Test-NoPlaceholder {
    param(
        [string]$Name,
        [string]$Text,
        [ValidateSet("WARN", "FAIL")]
        [string]$Severity = "FAIL"
    )

    Add-Check $Name (($null -ne $Text) -and (-not ($Text -match "%STEADYAGENT_HOME%"))) "Config still contains %STEADYAGENT_HOME%" $Severity
}

function Test-CodexManifestShape {
    param(
        [string]$Path,
        [string]$Label,
        [ValidateSet("WARN", "FAIL")]
        [string]$Severity = "FAIL"
    )

    $text = Read-TextFile $Path
    Test-FilePresent $Path ($Label + " exists") $Severity
    Test-NoPlaceholder ($Label + " has rendered paths") $text $Severity
    Test-TextPattern ($Label + " enables hooks feature") $text "\[features\]" "Missing [features] section" $Severity
    Test-TextPattern ($Label + " declares hook root") $text "windows_managed_dir" "Missing windows_managed_dir" $Severity
    Test-TextPattern ($Label + " registers SessionStart") $text "SessionStart" "Missing SessionStart hook event" $Severity
    Test-TextPattern ($Label + " registers UserPromptSubmit") $text "UserPromptSubmit" "Missing UserPromptSubmit hook event" $Severity
    Test-TextPattern ($Label + " registers PreToolUse") $text "PreToolUse" "Missing PreToolUse hook event" $Severity
    Test-TextPattern ($Label + " registers PermissionRequest") $text "PermissionRequest" "Missing PermissionRequest hook event" $Severity
    Test-TextPattern ($Label + " registers PostToolUse") $text "PostToolUse" "Missing PostToolUse hook event" $Severity
    Test-TextPattern ($Label + " registers PreCompact") $text "PreCompact" "Missing PreCompact hook event" $Severity
    Test-TextPattern ($Label + " registers context hook") $text "agent-hook-context[.]ps1" "Missing context hook" $Severity
    Test-TextPattern ($Label + " registers prompt reminder") $text "agent-hook-prompt-reminder[.]ps1" "Missing prompt reminder hook" $Severity
    Test-TextPattern ($Label + " registers command guard") $text "agent-hook-command-guard[.]ps1" "Missing command guard hook" $Severity
    Test-TextPattern ($Label + " registers file guard") $text "agent-hook-file-guard[.]ps1" "Missing file guard hook" $Severity
    Test-TextPattern ($Label + " registers permission guard") $text "agent-hook-permission-guard[.]ps1" "Missing permission guard hook" $Severity
    Test-TextPattern ($Label + " registers posttool audit") $text "agent-hook-posttool-audit[.]ps1" "Missing posttool audit hook" $Severity
    Test-TextPattern ($Label + " registers precompact hook") $text "agent-hook-precompact[.]ps1" "Missing precompact hook" $Severity
}

function Test-ClaudeSettingsShape {
    param(
        [string]$Path,
        [string]$Label,
        [ValidateSet("WARN", "FAIL")]
        [string]$Severity = "FAIL"
    )

    $text = Read-TextFile $Path
    Test-FilePresent $Path ($Label + " exists") $Severity
    Test-NoPlaceholder ($Label + " has rendered paths") $text $Severity
    Test-TextPattern ($Label + " contains hooks object") $text '"hooks"\s*:' "Missing hooks object" $Severity
    Test-TextPattern ($Label + " registers SessionStart") $text "SessionStart" "Missing SessionStart hook event" $Severity
    Test-TextPattern ($Label + " registers UserPromptSubmit") $text "UserPromptSubmit" "Missing UserPromptSubmit hook event" $Severity
    Test-TextPattern ($Label + " registers PreToolUse") $text "PreToolUse" "Missing PreToolUse hook event" $Severity
    Test-TextPattern ($Label + " registers PermissionRequest") $text "PermissionRequest" "Missing PermissionRequest hook event" $Severity
    Test-TextPattern ($Label + " registers PostToolUse") $text "PostToolUse" "Missing PostToolUse hook event" $Severity
    Test-TextPattern ($Label + " registers PreCompact") $text "PreCompact" "Missing PreCompact hook event" $Severity
    Test-TextPattern ($Label + " registers context hook") $text "agent-hook-context[.]ps1" "Missing context hook" $Severity
    Test-TextPattern ($Label + " registers prompt reminder") $text "agent-hook-prompt-reminder[.]ps1" "Missing prompt reminder hook" $Severity
    Test-TextPattern ($Label + " registers command guard") $text "agent-hook-command-guard[.]ps1" "Missing command guard hook" $Severity
    Test-TextPattern ($Label + " registers file guard") $text "agent-hook-file-guard[.]ps1" "Missing file guard hook" $Severity
    Test-TextPattern ($Label + " registers permission guard") $text "agent-hook-permission-guard[.]ps1" "Missing permission guard hook" $Severity
    Test-TextPattern ($Label + " registers posttool audit") $text "agent-hook-posttool-audit[.]ps1" "Missing posttool audit hook" $Severity
    Test-TextPattern ($Label + " registers precompact hook") $text "agent-hook-precompact[.]ps1" "Missing precompact hook" $Severity

    if ($null -ne $text) {
        try {
            $null = $text | ConvertFrom-Json
            Add-Result "PASS" ($Label + " parses as JSON") "OK"
        }
        catch {
            Add-Result $Severity ($Label + " parses as JSON") $_.Exception.Message
        }
    }
}

function Invoke-HookSmoke {
    param(
        [string]$RootPath,
        [string]$HostName
    )

    if ($SkipSmoke) {
        Add-Result "WARN" ($HostName + " hook smoke test") "Skipped by -SkipSmoke"
        return
    }

    $smokeScript = Join-Path $RootPath "tools/test-agent-hooks.ps1"
    if (-not (Test-Path -LiteralPath $smokeScript -PathType Leaf)) {
        Add-Result "FAIL" ($HostName + " hook smoke test") ("Missing file: " + $smokeScript)
        return
    }

    try {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $smokeScript
        $code = $LASTEXITCODE
        $text = ($output | Out-String)
        Add-Check ($HostName + " hook smoke test passes") (($code -eq 0) -and ($text -match "0 failed")) ("Smoke test failed. Output: " + $text.Trim())
    }
    catch {
        Add-Result "FAIL" ($HostName + " hook smoke test") $_.Exception.Message
    }
}

function Test-CommonInstall {
    param(
        [string]$RootPath,
        [string]$HostName,
        [string]$InstructionFile
    )

    Test-DirectoryPresent $RootPath ($HostName + " root exists")
    Test-FilePresent (Join-Path $RootPath $InstructionFile) ($HostName + " entry instructions installed")
    Test-FilePresent (Join-Path $RootPath "rules/workflow-routing.md") ($HostName + " workflow rules installed")
    Test-FilePresent (Join-Path $RootPath "rules/verification.md") ($HostName + " verification rules installed")
    Test-FilePresent (Join-Path $RootPath "rules/review-gates.md") ($HostName + " review rules installed")
    Test-FilePresent (Join-Path $RootPath "rules/context-management.md") ($HostName + " context rules installed")
    Test-FilePresent (Join-Path $RootPath "rules/safety-boundaries.md") ($HostName + " safety rules installed")
    Test-FilePresent (Join-Path $RootPath "skills/steadyagent-workflow/SKILL.md") ($HostName + " workflow skill installed")
    Test-FilePresent (Join-Path $RootPath "tools/hooks/agent-hook-utils.ps1") ($HostName + " hook utilities installed")
    Test-FilePresent (Join-Path $RootPath "tools/hooks/agent-hook-context.ps1") ($HostName + " context hook installed")
    Test-FilePresent (Join-Path $RootPath "tools/hooks/agent-hook-prompt-reminder.ps1") ($HostName + " prompt reminder hook installed")
    Test-FilePresent (Join-Path $RootPath "tools/hooks/agent-hook-command-guard.ps1") ($HostName + " command guard installed")
    Test-FilePresent (Join-Path $RootPath "tools/hooks/agent-hook-file-guard.ps1") ($HostName + " file guard installed")
    Test-FilePresent (Join-Path $RootPath "tools/hooks/agent-hook-permission-guard.ps1") ($HostName + " permission guard installed")
    Test-FilePresent (Join-Path $RootPath "tools/hooks/agent-hook-posttool-audit.ps1") ($HostName + " posttool audit hook installed")
    Test-FilePresent (Join-Path $RootPath "tools/hooks/agent-hook-precompact.ps1") ($HostName + " precompact hook installed")
    Test-FilePresent (Join-Path $RootPath "tools/test-agent-hooks.ps1") ($HostName + " hook smoke script installed")
    Test-FilePresent (Join-Path $RootPath "tools/diagnose-install.ps1") ($HostName + " diagnose script installed")
}

function Test-CodexInstall {
    Test-CommonInstall $CodexRoot "Codex" "AGENTS.md"
    Test-FilePresent (Join-Path $CodexRoot "tools/enable-codex-hooks.ps1") "Codex hook activation helper installed"
    Test-CodexManifestShape (Join-Path $CodexRoot "requirements.managed-hooks.example.toml") "Codex rendered hook example" "FAIL"
    $activeSeverity = if ($RequireHooksActive) { "FAIL" } else { "WARN" }
    Test-CodexManifestShape $CodexManagedConfigPath "Codex active managed hooks config" $activeSeverity
    Invoke-HookSmoke $CodexRoot "Codex"
}

function Test-ClaudeInstall {
    Test-CommonInstall $ClaudeRoot "Claude Code" "CLAUDE.md"
    Test-ClaudeSettingsShape (Join-Path $ClaudeRoot "settings.hooks.example.json") "Claude rendered hook example" "FAIL"
    $activeSeverity = if ($RequireHooksActive) { "FAIL" } else { "WARN" }
    Test-ClaudeSettingsShape $ClaudeSettingsPath "Claude active settings" $activeSeverity
    Invoke-HookSmoke $ClaudeRoot "Claude Code"
}

Write-Host "SteadyAgent install diagnosis"
Write-Host ("HostTarget: " + $HostTarget)
Write-Host ("CodexRoot: " + $CodexRoot)
Write-Host ("ClaudeRoot: " + $ClaudeRoot)
Write-Host ("CodexManagedConfigPath: " + $CodexManagedConfigPath)
Write-Host ("ClaudeSettingsPath: " + $ClaudeSettingsPath)
Write-Host ("RequireHooksActive: " + [string][bool]$RequireHooksActive)
Write-Host ""

if (($HostTarget -eq "Codex") -or ($HostTarget -eq "Both")) {
    Test-CodexInstall
}
if (($HostTarget -eq "Claude") -or ($HostTarget -eq "Both")) {
    Test-ClaudeInstall
}

foreach ($result in $script:results) {
    Write-Host ("{0} {1} - {2}" -f $result.Status, $result.Name, $result.Detail)
}

$passCount = @($script:results | Where-Object { $_.Status -eq "PASS" }).Count
$warnCount = @($script:results | Where-Object { $_.Status -eq "WARN" }).Count
$failCount = @($script:results | Where-Object { $_.Status -eq "FAIL" }).Count

Write-Host ""
Write-Host ("RESULT pass={0} warn={1} fail={2}" -f $passCount, $warnCount, $failCount)

if ($failCount -gt 0) {
    exit 1
}
exit 0
