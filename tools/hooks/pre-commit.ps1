[CmdletBinding()]
param(
    [int]$LargeFileMb = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (& git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Not a Git repository."
    exit 1
}
$root = ($root | Out-String).Trim()

$staged = @(& git diff --cached --name-only --diff-filter=ACMR)
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Could not read staged files."
    exit 1
}

$failures = New-Object System.Collections.Generic.List[string]
$limit = $LargeFileMb * 1MB
$secretPattern = "(?i)(" + "api" + "[_-]?key|access" + "[_-]?token|secret" + "[_-]?key|pass" + "word\s*=|BEGIN (RSA|OPENSSH|PRIVATE) KEY)"

foreach ($relative in $staged) {
    $blob = ":$relative"
    $sizeText = & git cat-file -s $blob 2>$null
    if ($LASTEXITCODE -ne 0) {
        continue
    }

    $size = [int64](($sizeText | Out-String).Trim())
    if ($size -gt $limit) {
        $failures.Add(("Large staged file: {0}" -f $relative)) | Out-Null
        continue
    }

    try {
        $text = & git show --textconv $blob 2>$null
        if ($LASTEXITCODE -ne 0) {
            continue
        }
        $text = ($text | Out-String)
        if ($text -match $secretPattern) {
            $failures.Add(("Possible secrets in staged file: {0}" -f $relative)) | Out-Null
        }
    }
    catch {
        continue
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Host ("[FAIL] {0}" -f $failure)
    }
    exit 1
}

Write-Host "[OK] pre-commit staged file scan passed."
