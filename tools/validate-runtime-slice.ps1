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

$runtimeFiles = @(
    "tools/hooks/agent-hook-utils.ps1",
    "tools/hooks/agent-hook-context.ps1",
    "tools/hooks/agent-hook-precompact.ps1",
    "tools/hooks/agent-hook-prompt-reminder.ps1",
    "tools/hooks/agent-hook-command-guard.ps1",
    "tools/hooks/agent-hook-file-guard.ps1",
    "tools/hooks/agent-hook-permission-guard.ps1",
    "tools/hooks/agent-hook-posttool-audit.ps1",
    "tools/test-agent-hooks.ps1",
    "templates/claude/settings.hooks.example.json",
    "templates/codex/requirements.managed-hooks.example.toml",
    "docs/hook-runtime.md",
    "docs/hook-runtime.zh-CN.md",
    "tools/validate-runtime-slice.ps1"
)

foreach ($file in $runtimeFiles) {
    Test-FileExists $file
}

foreach ($file in ($runtimeFiles | Where-Object { $_ -match "[.]ps1$" })) {
    Test-PowerShellSyntax $file
}

$utils = Read-Text "tools/hooks/agent-hook-utils.ps1"
Test-Contains "hook utils exposes command extraction" $utils "Get-HookCommands"
Test-Contains "hook utils exposes path extraction" $utils "Get-HookPaths"
Test-Contains "hook utils exposes dangerous command detection" $utils "Test-DangerousCommand"
Test-Contains "hook utils redacts audit text" $utils "Protect-HookLogText"

$commandGuard = Read-Text "tools/hooks/agent-hook-command-guard.ps1"
Test-Contains "command guard denies via PreToolUse" $commandGuard "permissionDecision"
Test-Contains "command guard uses shared dangerous command detector" $commandGuard "Test-DangerousCommand"

$fileGuard = Read-Text "tools/hooks/agent-hook-file-guard.ps1"
Test-Contains "file guard blocks env files" $fileGuard "[.]env"
Test-Contains "file guard supports apply_patch paths" $fileGuard "Get-HookPaths"

$permissionGuard = Read-Text "tools/hooks/agent-hook-permission-guard.ps1"
Test-Contains "permission guard emits PermissionRequest decision" $permissionGuard "PermissionRequest"
Test-Contains "permission guard denies dangerous escalation" $permissionGuard "behavior"

$preCompact = Read-Text "tools/hooks/agent-hook-precompact.ps1"
Test-Contains "precompact emits supported systemMessage" $preCompact "systemMessage"
Test-NoPatternInFiles "precompact avoids unsupported additionalContext" @("tools/hooks/agent-hook-precompact.ps1") "additionalContext"

$postTool = Read-Text "tools/hooks/agent-hook-posttool-audit.ps1"
Test-Contains "posttool audit never denies" $postTool "PostToolUse"
Test-Contains "posttool audit records command hash" $postTool "command_sha256"

$contextHook = Read-Text "tools/hooks/agent-hook-context.ps1"
Test-Contains "context hook restores PROJECT_STATE" $contextHook "PROJECT_STATE.md"
Test-Contains "context hook restores .agent/state.md" $contextHook "[.]agent/state[.]md"

$claudeTemplate = Read-Text "templates/claude/settings.hooks.example.json"
$anchoredShellMatcher = [regex]::Escape("^(Bash|PowerShell|shell_command|functions[.]shell_command|multi_tool_use[.]parallel)$")
$anchoredEditMatcher = [regex]::Escape("^(apply_patch|Edit|Write|MultiEdit|functions[.]apply_patch|multi_tool_use[.]parallel)$")
$anchoredAuditMatcher = [regex]::Escape("^(Bash|PowerShell|shell_command|functions[.]shell_command|multi_tool_use[.]parallel|apply_patch|Edit|Write|MultiEdit|functions[.]apply_patch)$")
Test-Contains "Claude template includes PermissionRequest" $claudeTemplate "PermissionRequest"
Test-Contains "Claude template includes PostToolUse" $claudeTemplate "PostToolUse"
Test-Contains "Claude template uses placeholder not private path" $claudeTemplate "STEADYAGENT_HOME"
Test-Contains "Claude template anchors shell matcher" $claudeTemplate $anchoredShellMatcher
Test-Contains "Claude template anchors edit matcher" $claudeTemplate $anchoredEditMatcher
Test-Contains "Claude template anchors audit matcher" $claudeTemplate $anchoredAuditMatcher

$codexTemplate = Read-Text "templates/codex/requirements.managed-hooks.example.toml"
Test-Contains "Codex template documents managed hooks" $codexTemplate "windows_managed_dir"
Test-Contains "Codex template includes PermissionRequest" $codexTemplate "PermissionRequest"
Test-Contains "Codex template includes PostToolUse" $codexTemplate "PostToolUse"
Test-Contains "Codex template anchors shell matcher" $codexTemplate $anchoredShellMatcher
Test-Contains "Codex template anchors edit matcher" $codexTemplate $anchoredEditMatcher
Test-Contains "Codex template anchors audit matcher" $codexTemplate $anchoredAuditMatcher

$hookDoc = Read-Text "docs/hook-runtime.md"
Test-Contains "hook runtime doc explains managed hooks" $hookDoc "managed hooks"
Test-Contains "hook runtime doc explains PermissionRequest" $hookDoc "PermissionRequest"
Test-Contains "hook runtime doc explains PostToolUse" $hookDoc "PostToolUse"

Push-Location $Root
try {
    Invoke-CheckedCommand "agent hook smoke test passes" {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\test-agent-hooks.ps1"
    } {
        param($output)
        $text = ($output | Out-String)
        return ($text -match "Smoke test:") -and ($text -match "0 failed")
    } "Hook runtime smoke test failed"
}
finally {
    Pop-Location
}

$slash = [string][char]47
$backslash = [string][char]92
$ownerName = "kha" + "lil"
$privatePathPattern = "(?i)(" + "C:" + [regex]::Escape($backslash + "Users" + $backslash) + "|C:" + [regex]::Escape($slash + "Users" + $slash) + "|E:" + [regex]::Escape($backslash) + "|D:" + [regex]::Escape($backslash) + "|" + $ownerName + ")"
$secretPattern = "(?i)(" + "api" + "[_-]?key|access" + "[_-]?token|secret" + "[_-]?key|pass" + "word\s*=|BEGIN (RSA|OPENSSH|PRIVATE) KEY)"
Test-NoPatternInFiles "runtime slice has no local private paths" $runtimeFiles $privatePathPattern
Test-NoPatternInFiles "runtime slice has no obvious secret material" $runtimeFiles $secretPattern

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
