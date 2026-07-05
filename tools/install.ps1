[CmdletBinding()]
param(
    [ValidateSet("Codex", "Claude", "Both")]
    [string]$HostTarget = "Both",

    [string]$TargetRoot,

    [switch]$Apply,

    [switch]$Overwrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Add-CopyPlan {
    param(
        [System.Collections.Generic.List[object]]$Plan,
        [string]$Source,
        [string]$Destination
    )

    $Plan.Add([PSCustomObject]@{
        Source = $Source
        Destination = $Destination
    }) | Out-Null
}

function Get-DefaultTargetRoot {
    param([string]$HostName)

    if ($HostName -eq "Codex") {
        return (Join-Path $HOME ".codex")
    }

    return (Join-Path $HOME ".claude")
}

function Add-HostPlan {
    param(
        [System.Collections.Generic.List[object]]$Plan,
        [string]$HostName,
        [string]$RootPath
    )

    if ($HostName -eq "Codex") {
        Add-CopyPlan $Plan (Join-Path $Root "templates/codex/AGENTS.md") (Join-Path $RootPath "AGENTS.md")
    }
    else {
        Add-CopyPlan $Plan (Join-Path $Root "templates/claude/CLAUDE.md") (Join-Path $RootPath "CLAUDE.md")
    }

    Add-CopyPlan $Plan (Join-Path $Root "rules") (Join-Path $RootPath "rules")
}

$plan = New-Object System.Collections.Generic.List[object]

if ($HostTarget -eq "Both") {
    if ($TargetRoot) {
        Add-HostPlan $plan "Codex" (Join-Path $TargetRoot "codex")
        Add-HostPlan $plan "Claude" (Join-Path $TargetRoot "claude")
    }
    else {
        Add-HostPlan $plan "Codex" (Get-DefaultTargetRoot "Codex")
        Add-HostPlan $plan "Claude" (Get-DefaultTargetRoot "Claude")
    }
}
else {
    $rootPath = if ($TargetRoot) { $TargetRoot } else { Get-DefaultTargetRoot $HostTarget }
    Add-HostPlan $plan $HostTarget $rootPath
}

if (-not $Apply) {
    Write-Host "DRY-RUN SteadyAgent install"
    Write-Host "DryRun mode is the default."
    Write-Host "No files were written. Re-run with -Apply to copy files."
    foreach ($item in $plan) {
        Write-Host ("WOULD copy {0} -> {1}" -f $item.Source, $item.Destination)
    }
    exit 0
}

$existing = @($plan | Where-Object { Test-Path -LiteralPath $_.Destination })
if (($existing.Count -gt 0) -and (-not $Overwrite)) {
    Write-Host "[FAIL] Existing targets detected. Re-run with -Overwrite after reviewing the list."
    foreach ($item in $existing) {
        Write-Host ("EXISTS {0}" -f $item.Destination)
    }
    exit 1
}

Write-Host "APPLY SteadyAgent install"
foreach ($item in $plan) {
    $destinationParent = Split-Path -Parent $item.Destination
    if (-not (Test-Path -LiteralPath $destinationParent)) {
        New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
    }

    Copy-Item -LiteralPath $item.Source -Destination $item.Destination -Recurse -Force
    Write-Host ("COPIED {0} -> {1}" -f $item.Source, $item.Destination)
}
