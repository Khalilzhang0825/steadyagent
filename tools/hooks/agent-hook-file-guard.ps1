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

$paths = @(Get-HookPaths -Event $event)
if ($paths.Count -eq 0) { exit 0 }

$reason = $null
$blockedPath = $null
foreach ($path in $paths) {
    $normalized = $path -replace "\\", "/"
    $leaf = Split-Path -Leaf $normalized
    $isEnvTemplate = $leaf -match '(?i)^\.env(?:\..+)?\.(example|sample|template)$'

    if ($normalized -match '/\.git/|^\.git/') {
        $reason = "Blocked: direct edits inside .git are not allowed."
    }
    elseif (($leaf -match '^\.env(\..+)?$') -and (-not $isEnvTemplate)) {
        $reason = "Blocked: do not edit real .env files through the agent. Use .env.example for templates."
    }
    elseif ($normalized -match '(?i)(^|/)(id_rsa|id_dsa|id_ecdsa|id_ed25519)(\.|$)') {
        $reason = "Blocked: SSH private key file. Ask before touching credentials."
    }
    elseif ($leaf -match '(?i)\.(pem|p12|pfx|key|keystore|jks|asc|ppk|pgpass)$') {
        $reason = "Blocked: key/certificate file. Ask before editing secrets."
    }
    elseif (($leaf -match '(?i)(^|[._-])(secret|secrets|credential|credentials)([._-]|$)') -and ($leaf -notmatch '(?i)[.](md|txt|example|sample|template|rst|adoc)$')) {
        $reason = "Blocked: credential-looking file name. Ask before editing secrets."
    }

    if ($reason) {
        $blockedPath = $path
        break
    }
}

if ($reason) {
    Write-SteadyAgentAuditLog -FileName "guard-audit.log" -Message ("[file-guard] " + $reason + " -- path: " + (Protect-HookLogText -Text $blockedPath))
    @{
        hookSpecificOutput = @{
            hookEventName = "PreToolUse"
            permissionDecision = "deny"
            permissionDecisionReason = $reason
        }
    } | ConvertTo-Json -Depth 5 -Compress
}
