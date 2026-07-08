[CmdletBinding()]
param()

try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$ErrorActionPreference = "Stop"

$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$hooks = Join-Path $sourceRoot "tools/hooks"
$script:pass = 0
$script:fail = 0

function Invoke-Hook {
    param(
        [string]$ScriptName,
        [string]$Json,
        [string]$LogDir
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File " + '"' + (Join-Path $hooks $ScriptName) + '"'
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    try { $psi.StandardErrorEncoding = [Text.Encoding]::UTF8 } catch { }
    if ($LogDir) { $psi.EnvironmentVariables["STEADYAGENT_LOG_DIR"] = $LogDir }
    $proc = [System.Diagnostics.Process]::Start($psi)
    if ($Json) { $proc.StandardInput.Write($Json) }
    $proc.StandardInput.Close()
    $out = $proc.StandardOutput.ReadToEnd()
    $err = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return [PSCustomObject]@{
        Output = $out
        Error = $err
        ExitCode = $proc.ExitCode
    }
}

function New-Event {
    param([hashtable]$H)
    return ($H | ConvertTo-Json -Compress -Depth 8)
}

function Assert-Contains {
    param([string]$Name, [string]$Text, [string]$Needle)
    if ($Text -and $Text.Contains($Needle)) {
        Write-Host ("PASS  " + $Name)
        $script:pass++
    }
    else {
        Write-Host ("FAIL  " + $Name + "  (missing: " + $Needle + ")")
        $script:fail++
    }
}

function Assert-NotContains {
    param([string]$Name, [string]$Text, [string]$Needle)
    if (-not $Text -or -not $Text.Contains($Needle)) {
        Write-Host ("PASS  " + $Name)
        $script:pass++
    }
    else {
        Write-Host ("FAIL  " + $Name + "  (should NOT contain: " + $Needle + ")")
        $script:fail++
    }
}

function Assert-NoDecision {
    param([string]$Name, [object]$Result)
    $hasDeny = $false
    if ($Result.Output) { $hasDeny = $Result.Output.Contains("deny") }
    if ($Result.ExitCode -eq 0 -and -not $Result.Error -and -not $hasDeny) {
        Write-Host ("PASS  " + $Name)
        $script:pass++
    }
    else {
        Write-Host ("FAIL  " + $Name + "  (exit=" + $Result.ExitCode + ", stderr=" + $Result.Error.Trim() + ", stdout=" + $Result.Output.Trim() + ")")
        $script:fail++
    }
}

function Assert-PreToolDeny {
    param([string]$Name, [object]$Result)
    $ok = $false
    try {
        $json = $Result.Output | ConvertFrom-Json
        $h = $json.hookSpecificOutput
        $ok = ($Result.ExitCode -eq 0 -and -not $Result.Error -and
            $h.hookEventName -eq "PreToolUse" -and
            $h.permissionDecision -eq "deny" -and
            $h.permissionDecisionReason)
    }
    catch {
        $ok = $false
    }
    if ($ok) {
        Write-Host ("PASS  " + $Name)
        $script:pass++
    }
    else {
        Write-Host ("FAIL  " + $Name + "  (invalid PreToolUse deny output)")
        $script:fail++
    }
}

function Assert-PermissionDeny {
    param([string]$Name, [object]$Result)
    $ok = $false
    try {
        $json = $Result.Output | ConvertFrom-Json
        $h = $json.hookSpecificOutput
        $ok = ($Result.ExitCode -eq 0 -and -not $Result.Error -and
            $h.hookEventName -eq "PermissionRequest" -and
            $h.decision.behavior -eq "deny" -and
            $h.decision.message)
    }
    catch {
        $ok = $false
    }
    if ($ok) {
        Write-Host ("PASS  " + $Name)
        $script:pass++
    }
    else {
        Write-Host ("FAIL  " + $Name + "  (invalid PermissionRequest deny output)")
        $script:fail++
    }
}

function Assert-PreCompactReminder {
    param([string]$Name, [object]$Result)
    $ok = $false
    try {
        $json = $Result.Output | ConvertFrom-Json
        $ok = ($Result.ExitCode -eq 0 -and -not $Result.Error -and
            $json.systemMessage -and
            $json.systemMessage.Contains("PRE-COMPACT") -and
            -not $json.PSObject.Properties["hookSpecificOutput"])
    }
    catch {
        $ok = $false
    }
    if ($ok) {
        Write-Host ("PASS  " + $Name)
        $script:pass++
    }
    else {
        Write-Host ("FAIL  " + $Name + "  (invalid PreCompact reminder output)")
        $script:fail++
    }
}

$base = [System.IO.Path]::GetTempPath()
$stateDir = Join-Path $base ("steadyagent-hook-state-" + [guid]::NewGuid().ToString("N"))
$agentStateDir = Join-Path $base ("steadyagent-hook-agent-state-" + [guid]::NewGuid().ToString("N"))
$emptyDir = Join-Path $base ("steadyagent-hook-empty-" + [guid]::NewGuid().ToString("N"))
$logDir = Join-Path $base ("steadyagent-hook-logs-" + [guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $agentStateDir ".agent") | Out-Null
New-Item -ItemType Directory -Force -Path $emptyDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Set-Content -LiteralPath (Join-Path $stateDir "PROJECT_STATE.md") -Value "# Test State", "- goal: SMOKE_MARKER_OK" -Encoding UTF8
Set-Content -LiteralPath (Join-Path $agentStateDir ".agent/state.md") -Value "# Agent State", "- goal: AGENT_STATE_MARKER_OK" -Encoding UTF8

try {
    Write-Host "=== SessionStart context ==="
    $o = Invoke-Hook "agent-hook-context.ps1" (New-Event @{ source = "startup"; cwd = $emptyDir }) $logDir
    Assert-Contains "startup: global reminder" $o.Output "SteadyAgent global reminder"
    Assert-NotContains "startup: no stale task state" $o.Output "TASK STATE"
    $o = Invoke-Hook "agent-hook-context.ps1" (New-Event @{ source = "compact"; cwd = $stateDir }) $logDir
    Assert-Contains "compact: restores PROJECT_STATE" $o.Output "TASK STATE restored after compact"
    Assert-Contains "compact: injects state content" $o.Output "SMOKE_MARKER_OK"
    $o = Invoke-Hook "agent-hook-context.ps1" (New-Event @{ source = "resume"; cwd = $agentStateDir }) $logDir
    Assert-Contains "resume: restores .agent state" $o.Output "TASK STATE restored after resume"
    Assert-Contains "resume: injects .agent content" $o.Output "AGENT_STATE_MARKER_OK"

    Write-Host ""
    Write-Host "=== PreCompact ==="
    $o = Invoke-Hook "agent-hook-precompact.ps1" "" $logDir
    Assert-PreCompactReminder "precompact: emits supported reminder" $o

    Write-Host ""
    Write-Host "=== UserPromptSubmit ==="
    $o = Invoke-Hook "agent-hook-prompt-reminder.ps1" (New-Event @{ prompt = "hello world" }) $logDir
    Assert-Contains "prompt: includes steadyagent rules" $o.Output "STEADYAGENT RULES"
    $o = Invoke-Hook "agent-hook-prompt-reminder.ps1" (New-Event @{ prompt = "please git push to origin" }) $logDir
    Assert-Contains "prompt: push risk line" $o.Output "RISK push"

    Write-Host ""
    Write-Host "=== PreToolUse command guard ==="
    $o = Invoke-Hook "agent-hook-command-guard.ps1" (New-Event @{ hook_event_name = "PreToolUse"; tool_name = "PowerShell"; tool_input = @{ command = "git reset --hard HEAD" } }) $logDir
    Assert-PreToolDeny "danger command: denied" $o
    $o = Invoke-Hook "agent-hook-command-guard.ps1" (New-Event @{ hook_event_name = "PreToolUse"; tool_name = "PowerShell"; tool_input = @{ command = "git status" } }) $logDir
    Assert-NoDecision "safe command: no denial" $o
    $wrapped = @{
        hook_event_name = "PreToolUse"
        tool_name = "multi_tool_use.parallel"
        tool_input = @{
            tool_uses = @(
                @{
                    recipient_name = "functions.shell_command"
                    parameters = @{ command = "git reset --hard HEAD" }
                }
            )
        }
    }
    $o = Invoke-Hook "agent-hook-command-guard.ps1" (New-Event $wrapped) $logDir
    Assert-PreToolDeny "wrapped command: denied" $o
    $o = Invoke-Hook "agent-hook-command-guard.ps1" (New-Event @{ hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = @{ command = "rm -r build" } }) $logDir
    Assert-PreToolDeny "recursive rm: denied" $o
    $o = Invoke-Hook "agent-hook-command-guard.ps1" (New-Event @{ hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = @{ command = "git checkout -- ." } }) $logDir
    Assert-PreToolDeny "git checkout worktree reset: denied" $o
    $o = Invoke-Hook "agent-hook-command-guard.ps1" (New-Event @{ hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = @{ command = "git checkout HEAD -- ." } }) $logDir
    Assert-PreToolDeny "git checkout treeish worktree reset: denied" $o
    $o = Invoke-Hook "agent-hook-command-guard.ps1" (New-Event @{ hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = @{ command = "git restore ." } }) $logDir
    Assert-PreToolDeny "git restore worktree reset: denied" $o
    $o = Invoke-Hook "agent-hook-command-guard.ps1" (New-Event @{ hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = @{ command = "git restore --worktree src" } }) $logDir
    Assert-PreToolDeny "git restore worktree option: denied" $o
    $o = Invoke-Hook "agent-hook-command-guard.ps1" (New-Event @{ hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = @{ command = "git add -- ." } }) $logDir
    Assert-PreToolDeny "git add dash dash dot: denied" $o
    $o = Invoke-Hook "agent-hook-command-guard.ps1" (New-Event @{ hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = @{ command = "git add :/" } }) $logDir
    Assert-PreToolDeny "git add repo root pathspec: denied" $o
    $o = Invoke-Hook "agent-hook-command-guard.ps1" (New-Event @{ hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = @{ command = "git add -u" } }) $logDir
    Assert-PreToolDeny "git add update shorthand: denied" $o
    $o = Invoke-Hook "agent-hook-command-guard.ps1" (New-Event @{ hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = @{ command = "git add --update" } }) $logDir
    Assert-PreToolDeny "git add update longhand: denied" $o

    Write-Host ""
    Write-Host "=== PermissionRequest ==="
    $o = Invoke-Hook "agent-hook-permission-guard.ps1" (New-Event @{ hook_event_name = "PermissionRequest"; tool_name = "PowerShell"; tool_input = @{ command = "git reset --hard HEAD" } }) $logDir
    Assert-PermissionDeny "danger permission: denied" $o
    $o = Invoke-Hook "agent-hook-permission-guard.ps1" (New-Event @{ hook_event_name = "PermissionRequest"; tool_name = "PowerShell"; tool_input = @{ command = "git status" } }) $logDir
    Assert-NoDecision "safe permission: no decision" $o

    Write-Host ""
    Write-Host "=== PreToolUse file guard ==="
    $o = Invoke-Hook "agent-hook-file-guard.ps1" (New-Event @{ hook_event_name = "PreToolUse"; tool_input = @{ file_path = "example/.env" } }) $logDir
    Assert-PreToolDeny "env file: denied" $o
    $patchText = "*** Begin Patch`n*** Update File: example/.env`n@@`n+SECRET=1`n*** End Patch"
    $o = Invoke-Hook "agent-hook-file-guard.ps1" (New-Event @{ hook_event_name = "PreToolUse"; tool_input = @{ command = $patchText } }) $logDir
    Assert-PreToolDeny "apply_patch env file: denied" $o
    $o = Invoke-Hook "agent-hook-file-guard.ps1" (New-Event @{ hook_event_name = "PreToolUse"; tool_input = @{ file_path = "docs/secret_sauce.md" } }) $logDir
    Assert-NoDecision "doc secret name: allowed" $o
    $o = Invoke-Hook "agent-hook-file-guard.ps1" (New-Event @{ hook_event_name = "PreToolUse"; tool_input = @{ file_path = "apps/web/.env.local.example" } }) $logDir
    Assert-NoDecision "env template: allowed" $o

    Write-Host ""
    Write-Host "=== PostToolUse audit ==="
    $o = Invoke-Hook "agent-hook-posttool-audit.ps1" (New-Event @{ hook_event_name = "PostToolUse"; tool_name = "PowerShell"; tool_input = @{ command = "git status token=example" }; tool_response = @{ exit_code = 0 } }) $logDir
    Assert-NoDecision "posttool audit: no denial" $o
    $auditLog = Join-Path $logDir "tool-audit.log"
    $auditText = if (Test-Path -LiteralPath $auditLog) { Get-Content -Raw -LiteralPath $auditLog } else { "" }
    Assert-Contains "posttool audit: log created" $auditText "command_sha256"
    Assert-Contains "posttool audit: redacts token" $auditText "[REDACTED]"
}
finally {
    foreach ($path in @($stateDir, $agentStateDir, $emptyDir, $logDir)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ""
Write-Host ("=== Smoke test: " + $script:pass + " passed, " + $script:fail + " failed ===")
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
