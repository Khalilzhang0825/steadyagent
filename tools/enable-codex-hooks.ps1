[CmdletBinding()]
param(
    [string]$SourceConfig,

    [string]$ManagedConfigPath,

    [string]$BackupRoot,

    [switch]$Apply,

    [switch]$ForceReplace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

function Get-ProgramDataRoot {
    $programData = $env:ProgramData
    if ($programData) {
        return $programData
    }
    $systemDrive = $env:SystemDrive
    if (-not $systemDrive) { $systemDrive = "C:" }
    return (Join-Path $systemDrive "ProgramData")
}

function Get-DefaultSourceConfig {
    $installedRoot = (Resolve-Path (Join-Path $PSScriptRoot "..") -ErrorAction SilentlyContinue)
    if ($installedRoot) {
        $installedConfig = Join-Path $installedRoot.Path "requirements.managed-hooks.example.toml"
        if (Test-Path -LiteralPath $installedConfig -PathType Leaf) {
            return $installedConfig
        }
    }
    return (Join-Path (Join-Path $HOME ".codex") "requirements.managed-hooks.example.toml")
}

function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Test-IsUnderPath {
    param(
        [string]$Child,
        [string]$Parent
    )

    $childFull = [System.IO.Path]::GetFullPath($Child).TrimEnd('\', '/')
    $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\', '/')
    if ($childFull.Length -lt $parentFull.Length) {
        return $false
    }
    return $childFull.StartsWith($parentFull, [System.StringComparison]::OrdinalIgnoreCase)
}

function Read-TextFile {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Test-ManifestShape {
    param([string]$Text)

    if (-not $Text) { return $false }
    return ($Text -match "\[features\]") -and
        ($Text -match "\[hooks\]") -and
        ($Text -match "windows_managed_dir") -and
        ($Text -match "agent-hook-context[.]ps1") -and
        ($Text -match "agent-hook-command-guard[.]ps1") -and
        ($Text -match "agent-hook-file-guard[.]ps1") -and
        ($Text -match "agent-hook-precompact[.]ps1") -and
        (-not ($Text -match "%STEADYAGENT_HOME%"))
}

if (-not $SourceConfig) {
    $SourceConfig = Get-DefaultSourceConfig
}
if (-not $ManagedConfigPath) {
    $ManagedConfigPath = Join-Path (Get-ProgramDataRoot) "OpenAI/Codex/requirements.toml"
}
if (-not $BackupRoot) {
    $BackupRoot = Join-Path (Join-Path $HOME ".codex") "backups/managed-hooks"
}

$sourceExists = Test-Path -LiteralPath $SourceConfig -PathType Leaf
$sourceText = $null
$sourceValid = $false
if ($sourceExists) {
    $sourceText = Read-TextFile $SourceConfig
    $sourceValid = Test-ManifestShape $sourceText
}

$targetExists = Test-Path -LiteralPath $ManagedConfigPath -PathType Leaf
$targetText = $null
$targetSame = $false
if ($targetExists) {
    $targetText = Read-TextFile $ManagedConfigPath
    $targetSame = ($sourceText -ne $null) -and ($targetText -eq $sourceText)
}

$admin = Test-IsAdministrator
$programDataRoot = Get-ProgramDataRoot
$targetUnderProgramData = Test-IsUnderPath $ManagedConfigPath $programDataRoot

if (-not $Apply) {
    Write-Host "DRY-RUN SteadyAgent Codex hook activation"
}
else {
    Write-Host "APPLY SteadyAgent Codex hook activation"
}
Write-Host ("SourceConfig: " + $SourceConfig)
Write-Host ("ManagedConfigPath: " + $ManagedConfigPath)
Write-Host ("BackupRoot: " + $BackupRoot)
Write-Host ("SourceExists: " + [string]$sourceExists)
Write-Host ("SourceValid: " + [string]$sourceValid)
Write-Host ("TargetExists: " + [string]$targetExists)
Write-Host ("TargetSameAsSource: " + [string]$targetSame)
Write-Host ("TargetUnderProgramData: " + [string]$targetUnderProgramData)
Write-Host ("Administrator: " + [string]$admin)

if (-not $sourceExists) {
    Write-Host "[FAIL] Source config is missing. Run install.ps1 -HostTarget Codex -Apply first, or pass -SourceConfig."
    exit 1
}

if (-not $sourceValid) {
    Write-Host "[FAIL] Source config is not a rendered SteadyAgent Codex managed-hook manifest."
    Write-Host "[FAIL] Use the installed requirements.managed-hooks.example.toml, not the repository template with placeholders."
    exit 1
}

if ($targetExists -and (-not $targetSame) -and (-not $ForceReplace)) {
    Write-Host "[WARN] Target managed config already exists and differs from the SteadyAgent manifest."
    Write-Host "[WARN] Dry-run will not replace it. For apply, merge manually or pass -ForceReplace after reviewing the target file."
    if ($Apply) {
        exit 1
    }
}

if ($targetUnderProgramData -and $Apply -and (-not $admin)) {
    Write-Host "[FAIL] Writing the Codex managed config under ProgramData requires an elevated PowerShell session."
    Write-Host "[FAIL] Re-open PowerShell as Administrator and run this command again."
    exit 1
}

if (-not $Apply) {
    if ($targetExists -and $targetSame) {
        Write-Host "WOULD no-op: target already matches source."
    }
    elseif ($targetExists) {
        Write-Host "WOULD backup existing target, then replace it only with -Apply -ForceReplace."
    }
    else {
        Write-Host "WOULD create target parent directory and write the SteadyAgent managed hook manifest."
    }
    Write-Host "No files were written. Re-run with -Apply after reviewing the plan."
    exit 0
}

$targetParent = Split-Path -Parent $ManagedConfigPath
if (-not (Test-Path -LiteralPath $targetParent -PathType Container)) {
    New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
    Write-Host ("CREATED " + $targetParent)
}

if ($targetExists -and $targetSame) {
    Write-Host "[OK] Target already matches the SteadyAgent manifest."
    Write-Host "Restart Codex so the managed hooks are registered."
    exit 0
}

if ($targetExists) {
    if (-not (Test-Path -LiteralPath $BackupRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = Join-Path $BackupRoot ("requirements.toml." + $timestamp + ".bak")
    Copy-Item -LiteralPath $ManagedConfigPath -Destination $backupPath -Force
    Write-Host ("BACKUP " + $ManagedConfigPath + " -> " + $backupPath)
}

[System.IO.File]::WriteAllText($ManagedConfigPath, $sourceText, [System.Text.Encoding]::UTF8)
Write-Host ("WROTE " + $ManagedConfigPath)
Write-Host "Restart Codex so the managed hooks are registered."
exit 0
