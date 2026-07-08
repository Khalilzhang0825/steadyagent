[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "agent-hook-utils.ps1")

# PostToolUse is audit-only: this hook writes evidence and never emits a deny decision.
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

$eventName = ""
$toolName = ""
$command = ""
$commandHash = ""
$path = ""
$status = ""

if (Test-HookProperty -Object $event -Name "hook_event_name") { $eventName = [string]$event.hook_event_name }
if (Test-HookProperty -Object $event -Name "tool_name") { $toolName = [string]$event.tool_name }

$commands = @(Get-HookCommands -Event $event)
if ($commands.Count -gt 0) {
    $command = (($commands | ForEach-Object { Protect-HookLogText -Text $_ }) -join " ; ")
    $commandHash = Get-Sha256Hex -Text ($commands -join "`n")
}

$paths = @(Get-HookPaths -Event $event)
if ($paths.Count -gt 0) {
    $path = (($paths | ForEach-Object { Protect-HookLogText -Text $_ }) -join " ; ")
}

if (Test-HookProperty -Object $event -Name "tool_response") {
    foreach ($name in @("exit_code", "status", "success")) {
        if (Test-HookProperty -Object $event.tool_response -Name $name) {
            $status = [string]$event.tool_response.$name
            break
        }
    }
}

if (-not $toolName -and -not $command -and -not $path) { exit 0 }

try {
    $logDir = Get-SteadyAgentLogDir
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }
    $logFile = Join-Path $logDir "tool-audit.log"
    if ((Test-Path -LiteralPath $logFile) -and ((Get-Item -LiteralPath $logFile).Length -gt 10MB)) {
        $archive = Join-Path $logDir ("tool-audit-" + (Get-Date -Format "yyyyMMddHHmmss") + ".log")
        Move-Item -LiteralPath $logFile -Destination $archive -Force
    }

    $max = 300
    if ($command.Length -gt $max) { $command = $command.Substring(0, $max) + "...[truncated]" }
    $entry = [ordered]@{
        ts = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        event = $eventName
        tool = $toolName
        command = $command
        command_sha256 = $commandHash
        path = $path
        status = $status
    }
    $line = ($entry | ConvertTo-Json -Compress)
    [System.IO.File]::AppendAllText($logFile, $line + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
} catch { }
