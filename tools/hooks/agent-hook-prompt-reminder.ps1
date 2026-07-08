[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$reader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), [System.Text.Encoding]::UTF8)
$raw = $reader.ReadToEnd()
$reader.Dispose()
$promptText = ""
if ($raw) {
    try {
        $event = $raw | ConvertFrom-Json
        if ($event.PSObject.Properties.Name -contains "prompt") {
            $promptText = [string]$event.prompt
        }
    }
    catch { }
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("[STEADYAGENT RULES] Check scope, run preflight before edits, verify before claiming success, checkpoint with explicit files, and do not push/deploy/delete/install without explicit approval.")

$p = $promptText.ToLowerInvariant()
function Test-Hit {
    param([string[]]$Patterns)
    foreach ($x in $Patterns) {
        if ($p -match $x) { return $true }
    }
    return $false
}

if (Test-Hit @("reset", "--hard", "rollback", "revert")) {
    $lines.Add("RISK rollback: no hard reset or clean by default; explain scope and get approval.")
}
if (Test-Hit @("push", "publish", "deploy", "release")) {
    $lines.Add("RISK push/deploy/release: explicit approval required.")
}
if (Test-Hit @("delete", "remove", "rm ", "recurse", "drop table")) {
    $lines.Add("RISK delete: confirm target paths and avoid unconfirmed recursive deletes.")
}
if (Test-Hit @("install", "dependency", "download", "dataset", "model")) {
    $lines.Add("INSTALL/STORAGE: confirm necessity, source, and install/cache location first.")
}
if (Test-Hit @("commit", "checkpoint")) {
    $lines.Add("COMMIT: review diff/status and stage only task files.")
}
if (Test-Hit @("review", "audit")) {
    $lines.Add("REVIEW: risky or multi-file work needs fresh-context independent review.")
}

$text = ($lines -join "`n")
@{
    hookSpecificOutput = @{
        hookEventName = "UserPromptSubmit"
        additionalContext = $text
    }
} | ConvertTo-Json -Depth 5 -Compress
