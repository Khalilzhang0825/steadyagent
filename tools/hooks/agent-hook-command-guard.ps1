[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "agent-hook-utils.ps1")

$reader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), [System.Text.Encoding]::UTF8)
$raw = $reader.ReadToEnd()
$reader.Dispose()
if (-not $raw) { exit 0 }

try {
    $event = $raw | ConvertFrom-Json
}
catch {
    exit 0
}

$commands = @(Get-HookCommands -Event $event)
if ($commands.Count -eq 0) { exit 0 }

$reason = $null
$blockedCommand = $null
foreach ($candidate in $commands) {
    $candidateReason = Test-DangerousCommand -Command $candidate
    if ($candidateReason) {
        $reason = $candidateReason
        $blockedCommand = $candidate
        break
    }
}

if ($reason) {
    Write-SteadyAgentAuditLog -FileName "guard-audit.log" -Message ("[command-guard] " + $reason + " -- cmd: " + (Protect-HookLogText -Text $blockedCommand))
    @{
        hookSpecificOutput = @{
            hookEventName = "PreToolUse"
            permissionDecision = "deny"
            permissionDecisionReason = $reason
        }
    } | ConvertTo-Json -Depth 5 -Compress
}
