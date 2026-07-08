[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [Parameter(Mandatory = $true)]
    [string[]]$Files,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Files.Count -eq 0) {
    Write-Host "[FAIL] Pass at least one explicit file path with -Files."
    exit 1
}

$root = (& git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Not a Git repository."
    exit 1
}

if ($DryRun) {
    Write-Host "DRY-RUN checkpoint"
    Write-Host ("Repository: {0}" -f (($root | Out-String).Trim()))
    Write-Host "Would stage explicit files:"
    foreach ($file in $Files) {
        Write-Host ("  {0}" -f $file)
    }
    Write-Host "Would commit with the provided message."
    exit 0
}

$allowed = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($file in $Files) {
    [void]$allowed.Add(($file -replace "\\", "/"))
}

$preStaged = @(& git diff --cached --name-only)
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Could not inspect staged files."
    exit 1
}

$unexpectedPreStaged = @($preStaged | Where-Object { -not $allowed.Contains(($_ -replace "\\", "/")) })
if ($unexpectedPreStaged.Count -gt 0) {
    Write-Host "[FAIL] Existing staged files are outside -Files. Commit or unstage them first."
    foreach ($file in $unexpectedPreStaged) {
        Write-Host ("  {0}" -f $file)
    }
    exit 1
}

Write-Host "[INFO] Staging explicit files:"
foreach ($file in $Files) {
    Write-Host ("  {0}" -f $file)
}

& git add -- @Files
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] git add failed."
    exit 1
}

$staged = & git diff --cached --name-only
if ($LASTEXITCODE -ne 0 -or @($staged).Count -eq 0) {
    Write-Host "[FAIL] No staged files."
    exit 1
}

$unexpectedStaged = @($staged | Where-Object { -not $allowed.Contains(($_ -replace "\\", "/")) })
if ($unexpectedStaged.Count -gt 0) {
    Write-Host "[FAIL] Staged files are outside -Files."
    foreach ($file in $unexpectedStaged) {
        Write-Host ("  {0}" -f $file)
    }
    exit 1
}

Write-Host "[INFO] Staged files:"
foreach ($file in $staged) {
    Write-Host ("  {0}" -f $file)
}

& git commit -m $Message
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] git commit failed."
    exit 1
}

Write-Host "[OK] Checkpoint commit created."
