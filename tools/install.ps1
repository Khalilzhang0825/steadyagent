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
        Kind = "Copy"
        Source = $Source
        Destination = $Destination
        SteadyAgentHome = $null
    }) | Out-Null
}

function Add-RenderPlan {
    param(
        [System.Collections.Generic.List[object]]$Plan,
        [string]$Source,
        [string]$Destination,
        [string]$SteadyAgentHome
    )

    $Plan.Add([PSCustomObject]@{
        Kind = "Render"
        Source = $Source
        Destination = $Destination
        SteadyAgentHome = $SteadyAgentHome
    }) | Out-Null
}

function Convert-SteadyAgentHomeForTemplate {
    param(
        [string]$Path,
        [string]$TemplatePath
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($TemplatePath -match "[.]json$") {
        return $fullPath.Replace("\", "\\")
    }
    return $fullPath
}

function Write-RenderedTemplate {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$SteadyAgentHome
    )

    $template = [System.IO.File]::ReadAllText($Source, [System.Text.Encoding]::UTF8)
    $replacement = Convert-SteadyAgentHomeForTemplate -Path $SteadyAgentHome -TemplatePath $Source
    $rendered = $template.Replace("%STEADYAGENT_HOME%", $replacement)
    [System.IO.File]::WriteAllText($Destination, $rendered, [System.Text.Encoding]::UTF8)
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
        [System.Collections.Generic.List[string]]$InstallRoots,
        [string]$HostName,
        [string]$RootPath
    )

    $InstallRoots.Add($RootPath) | Out-Null

    if ($HostName -eq "Codex") {
        Add-CopyPlan $Plan (Join-Path $Root "templates/codex/AGENTS.md") (Join-Path $RootPath "AGENTS.md")
        Add-RenderPlan $Plan (Join-Path $Root "templates/codex/requirements.managed-hooks.example.toml") (Join-Path $RootPath "requirements.managed-hooks.example.toml") $RootPath
    }
    else {
        Add-CopyPlan $Plan (Join-Path $Root "templates/claude/CLAUDE.md") (Join-Path $RootPath "CLAUDE.md")
        Add-RenderPlan $Plan (Join-Path $Root "templates/claude/settings.hooks.example.json") (Join-Path $RootPath "settings.hooks.example.json") $RootPath
    }

    Add-CopyPlan $Plan (Join-Path $Root "rules") (Join-Path $RootPath "rules")
    Add-CopyPlan $Plan (Join-Path $Root "skills/steadyagent-workflow") (Join-Path $RootPath "skills/steadyagent-workflow")
    $hookSourceRoot = Join-Path $Root "tools/hooks"
    foreach ($hookScript in @(Get-ChildItem -LiteralPath $hookSourceRoot -Filter "agent-hook-*.ps1" | Sort-Object Name)) {
        Add-CopyPlan $Plan $hookScript.FullName (Join-Path $RootPath ("tools/hooks/" + $hookScript.Name))
    }
    Add-CopyPlan $Plan (Join-Path $Root "tools/test-agent-hooks.ps1") (Join-Path $RootPath "tools/test-agent-hooks.ps1")
    Add-CopyPlan $Plan (Join-Path $Root "docs/hook-runtime.md") (Join-Path $RootPath "docs/hook-runtime.md")
    Add-CopyPlan $Plan (Join-Path $Root "docs/hook-runtime.zh-CN.md") (Join-Path $RootPath "docs/hook-runtime.zh-CN.md")
}

$plan = New-Object System.Collections.Generic.List[object]
$installRoots = New-Object System.Collections.Generic.List[string]

if ($HostTarget -eq "Both") {
    if ($TargetRoot) {
        Add-HostPlan $plan $installRoots "Codex" (Join-Path $TargetRoot "codex")
        Add-HostPlan $plan $installRoots "Claude" (Join-Path $TargetRoot "claude")
    }
    else {
        Add-HostPlan $plan $installRoots "Codex" (Get-DefaultTargetRoot "Codex")
        Add-HostPlan $plan $installRoots "Claude" (Get-DefaultTargetRoot "Claude")
    }
}
else {
    $rootPath = if ($TargetRoot) { $TargetRoot } else { Get-DefaultTargetRoot $HostTarget }
    Add-HostPlan $plan $installRoots $HostTarget $rootPath
}

if (-not $Apply) {
    Write-Host "DRY-RUN SteadyAgent install"
    Write-Host "DryRun mode is the default."
    Write-Host "No files were written. Re-run with -Apply to copy files."
    foreach ($item in $plan) {
        $verb = if ($item.Kind -eq "Render") { "render" } else { "copy" }
        Write-Host ("WOULD {0} {1} -> {2}" -f $verb, $item.Source, $item.Destination)
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

    if ($item.Kind -eq "Render") {
        Write-RenderedTemplate -Source $item.Source -Destination $item.Destination -SteadyAgentHome $item.SteadyAgentHome
        Write-Host ("RENDERED {0} -> {1}" -f $item.Source, $item.Destination)
    }
    else {
        Copy-Item -LiteralPath $item.Source -Destination $item.Destination -Recurse -Force
        Write-Host ("COPIED {0} -> {1}" -f $item.Source, $item.Destination)
    }
}
