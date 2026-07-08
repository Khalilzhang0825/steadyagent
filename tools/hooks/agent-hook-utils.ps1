[CmdletBinding()]
param()

Set-StrictMode -Version Latest

function Test-HookProperty {
    param(
        [object]$Object,
        [string]$Name
    )
    return ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name)
}

function Get-HookPropertyValue {
    param(
        [object]$Object,
        [string]$Name
    )
    if (Test-HookProperty -Object $Object -Name $Name) {
        return $Object.$Name
    }
    return $null
}

function Add-HookString {
    param(
        [System.Collections.Generic.List[string]]$List,
        [object]$Value
    )
    if ($null -eq $Value) { return }
    $text = [string]$Value
    if ($text.Trim().Length -gt 0) { $List.Add($text) }
}

function Get-HookToolName {
    param([object]$Object)
    foreach ($name in @("tool_name", "recipient_name", "name")) {
        $value = Get-HookPropertyValue -Object $Object -Name $name
        if ($value) { return [string]$value }
    }
    return ""
}

function Test-ShellToolName {
    param([string]$Name)
    return ($Name -match "(?i)^(Bash|PowerShell|shell_command|functions[.]shell_command)$")
}

function Add-HookCommandsFromWrapper {
    param(
        [object]$Object,
        [System.Collections.Generic.List[string]]$Commands
    )
    if ($null -eq $Object) { return }

    $toolUses = Get-HookPropertyValue -Object $Object -Name "tool_uses"
    if ($toolUses) {
        foreach ($toolUse in @($toolUses)) {
            $toolName = Get-HookToolName -Object $toolUse
            if (Test-ShellToolName -Name $toolName) {
                $parameters = Get-HookPropertyValue -Object $toolUse -Name "parameters"
                $command = Get-HookPropertyValue -Object $parameters -Name "command"
                Add-HookString -List $Commands -Value $command
            }
            Add-HookCommandsFromWrapper -Object (Get-HookPropertyValue -Object $toolUse -Name "parameters") -Commands $Commands
            Add-HookCommandsFromWrapper -Object (Get-HookPropertyValue -Object $toolUse -Name "tool_input") -Commands $Commands
        }
    }
}

function Get-HookCommands {
    param([object]$Event)
    $commands = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Event) { return @() }

    $topTool = Get-HookToolName -Object $Event
    foreach ($containerName in @("tool_input", "input", "parameters")) {
        $container = Get-HookPropertyValue -Object $Event -Name $containerName
        if ($null -eq $container) { continue }
        $command = Get-HookPropertyValue -Object $container -Name "command"
        if ($command -and (($topTool -eq "") -or (Test-ShellToolName -Name $topTool))) {
            Add-HookString -List $commands -Value $command
        }
        Add-HookCommandsFromWrapper -Object $container -Commands $commands
    }
    Add-HookCommandsFromWrapper -Object $Event -Commands $commands

    return @($commands | Select-Object -Unique)
}

function Add-PatchPathsFromText {
    param(
        [string]$Text,
        [System.Collections.Generic.List[string]]$Paths
    )
    if (-not $Text) { return }
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match '^\*\*\* (Add|Update|Delete) File: (.+)$') {
            $candidate = $Matches[2].Trim()
            if ($candidate.Length -gt 0) { $Paths.Add($candidate) }
        }
        elseif ($line -match '^\*\*\* Move to: (.+)$') {
            $candidate = $Matches[1].Trim()
            if ($candidate.Length -gt 0) { $Paths.Add($candidate) }
        }
    }
}

function Add-HookPathsFromValue {
    param(
        [object]$Value,
        [System.Collections.Generic.List[string]]$Paths
    )
    if ($null -eq $Value) { return }

    if ($Value -is [string]) {
        Add-PatchPathsFromText -Text ([string]$Value) -Paths $Paths
        return
    }

    foreach ($name in @("file_path", "path")) {
        $path = Get-HookPropertyValue -Object $Value -Name $name
        if ($path) { Add-HookString -List $Paths -Value $path }
    }

    foreach ($name in @("command", "patch", "content", "changes")) {
        $text = Get-HookPropertyValue -Object $Value -Name $name
        if ($text -is [string]) {
            Add-PatchPathsFromText -Text ([string]$text) -Paths $Paths
        }
    }

    foreach ($name in @("input", "tool_input", "parameters")) {
        Add-HookPathsFromValue -Value (Get-HookPropertyValue -Object $Value -Name $name) -Paths $Paths
    }

    $toolUses = Get-HookPropertyValue -Object $Value -Name "tool_uses"
    if ($toolUses) {
        foreach ($toolUse in @($toolUses)) {
            Add-HookPathsFromValue -Value $toolUse -Paths $Paths
        }
    }
}

function Get-HookPaths {
    param([object]$Event)
    $paths = New-Object System.Collections.Generic.List[string]
    if ($null -ne $Event) { Add-HookPathsFromValue -Value $Event -Paths $paths }
    return @($paths | Select-Object -Unique)
}

function Test-DangerousCommand {
    param([string]$Command)
    if (-not $Command) { return $null }
    $cmd = ($Command -replace "[`r`n]+", " ")
    $argValue = '(?:"[^"]+"|''[^'']+''|\S+)'
    $gitPrefix = "\bgit(?:[.]exe)?\b(?:\s+(?:-[A-Za-z]\s+$argValue|--[A-Za-z0-9-]+(?:=$argValue|\s+$argValue)?))*\s+"

    if ($cmd -match ("(?i)" + $gitPrefix + "reset\s+--hard\b")) {
        return "Blocked: 'git reset --hard' can destroy uncommitted work. Ask for explicit approval and explain the rollback scope."
    }
    if ($cmd -match ("(?i)" + $gitPrefix + "clean\b[^\r\n]*-[A-Za-z]*f")) {
        return "Blocked: 'git clean -f' can delete untracked files. Ask for explicit approval and list target paths."
    }
    if ($cmd -match "(?i)\bgit(?:[.]exe)?\b[^\r\n]*\bpush\b[^\r\n]*(--force\b|-f\b|--force-with-lease|\s\+\S+)") {
        return "Blocked: force push requires explicit approval."
    }
    if ($cmd -match ("(?i)" + $gitPrefix + "checkout\b[^\r\n]*\s+--\s+\S+")) {
        return "Blocked: 'git checkout -- <path>' can discard worktree changes. Ask for explicit approval and list target paths."
    }
    if ($cmd -match ("(?i)" + $gitPrefix + "restore\b([^\r\n]*)")) {
        $restoreArgs = $Matches[1]
        if (($restoreArgs -match "(?i)(^|\s)--worktree\b") -or ($restoreArgs -notmatch "(?i)(^|\s)--staged\b")) {
            return "Blocked: 'git restore' can discard worktree changes. Ask for explicit approval and list target paths."
        }
    }
    if ($cmd -match ("(?i)" + $gitPrefix + "add\b(?:\s+(?:--|-[A-Za-z]+|--[A-Za-z0-9-]+(?:=$argValue|\s+$argValue)?))*\s+(\.|:/|-A|--all|-u|--update)(\s|$)")) {
        return "Blocked: avoid blanket staging. Stage explicit files."
    }
    if ($cmd -match "(?i)\brm\s+-[A-Za-z]*r[A-Za-z]*f|\brm\s+-[A-Za-z]*f[A-Za-z]*r") {
        return "Blocked: recursive force delete requires explicit approval and verified target paths."
    }
    if ($cmd -match "(?i)\b(Remove-Item|rm|ri)\b[^\r\n]*(?:-(?:Recurse|Rec)\b|\s-r\b)") {
        return "Blocked: recursive Remove-Item requires explicit approval and verified target paths."
    }
    if ($cmd -match "(?i)\b(cmd(?:[.]exe)?\s+/c\s+)?(rmdir|rd)\b[^\r\n]*(/s\b|-Recurse|\s-r\b)") {
        return "Blocked: recursive directory delete requires explicit approval and verified target paths."
    }
    if ($cmd -match "(?i)\b(del|erase)\b[^\r\n]*/s\b") {
        return "Blocked: recursive delete requires explicit approval and verified target paths."
    }
    if ($cmd -match "(?i)\b(powershell(?:[.]exe)?|pwsh(?:[.]exe)?)\b[^\r\n]*\s-(EncodedCommand|enc|e|ec)\b") {
        return "Blocked: encoded PowerShell commands hide intent. Use readable commands."
    }
    if (($cmd -match "(?i)(>>?|Out-File|Set-Content|Add-Content|Tee-Object)") -and ($cmd -match "(?i)(\.env\b|id_rsa|id_dsa|id_ecdsa|id_ed25519|\.pem\b|\.p12\b|\.pfx\b|\.key\b|\.keystore\b|\.pgpass\b)")) {
        return "Blocked: writing to a secret/.env file via shell redirection is not allowed."
    }

    return $null
}

function Protect-HookLogText {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    $redacted = [string]$Text
    $redacted = [regex]::Replace($redacted, '(?i)(Authorization\s*:\s*Bearer\s+)[^\s"'';]+', '$1[REDACTED]')
    $redacted = [regex]::Replace($redacted, '(?i)(\b(?:password|passwd|pwd|token|api[_-]?key|secret|client_secret)\b\s*[:=]\s*)(["'']?)[^\s"'';]+(\2)', '$1$2[REDACTED]$3')
    $redacted = [regex]::Replace($redacted, '(?i)\bsk-[A-Za-z0-9_-]{8,}\b', 'sk-[REDACTED]')
    $redacted = [regex]::Replace($redacted, '\bgh[pousr]_[A-Za-z0-9_]{8,}\b', 'gh_[REDACTED]')
    $redacted = [regex]::Replace($redacted, '\bAKIA[0-9A-Z]{16}\b', 'AKIA[REDACTED]')
    $redacted = [regex]::Replace($redacted, '(?i)(://[^:/@\s]+:)[^@\s]+(@)', '$1[REDACTED]$2')
    return $redacted
}

function Get-Sha256Hex {
    param([string]$Text)
    if ($null -eq $Text) { $Text = "" }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hash = $sha.ComputeHash($bytes)
        return (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
    }
    finally {
        $sha.Dispose()
    }
}

function Get-SteadyAgentLogDir {
    $configured = $env:STEADYAGENT_LOG_DIR
    if ($configured) { return $configured }
    $base = $env:LOCALAPPDATA
    if (-not $base) { $base = [System.IO.Path]::GetTempPath() }
    return (Join-Path $base "SteadyAgent/logs")
}

function Write-SteadyAgentAuditLog {
    param(
        [string]$FileName,
        [string]$Message,
        [int64]$MaxBytes = 5242880
    )
    try {
        $logDir = Get-SteadyAgentLogDir
        if (-not (Test-Path -LiteralPath $logDir)) {
            New-Item -ItemType Directory -Force -Path $logDir | Out-Null
        }
        $logFile = Join-Path $logDir $FileName
        if ((Test-Path -LiteralPath $logFile) -and ((Get-Item -LiteralPath $logFile).Length -gt $MaxBytes)) {
            $archive = Join-Path $logDir (($FileName -replace "[.]log$", "") + "-" + (Get-Date -Format "yyyyMMddHHmmss") + ".log")
            Move-Item -LiteralPath $logFile -Destination $archive -Force
        }
        $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " " + $Message
        [System.IO.File]::AppendAllText($logFile, $line + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
    } catch { }
}
