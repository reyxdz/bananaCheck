$ErrorActionPreference = 'Stop'

function Require-Command {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found on PATH. See README.md prerequisites."
    }
}

@('flutter', 'dart', 'java', 'adb') | ForEach-Object { Require-Command $_ }

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$pythonVersion = ''
$pythonExitCode = 1
if (Get-Command py -ErrorAction SilentlyContinue) {
    $pythonVersion = (& py -3.11 --version 2>&1 | Out-String).Trim()
    $pythonExitCode = $LASTEXITCODE
}

$pythonExecutable = Join-Path $env:LocalAppData 'Programs\Python\Python311\python.exe'
if (($pythonExitCode -ne 0 -or $pythonVersion -notmatch '^Python 3\.11\.') -and
    (Test-Path $pythonExecutable)) {
    $pythonVersion = (& $pythonExecutable --version 2>&1 | Out-String).Trim()
    $pythonExitCode = $LASTEXITCODE
}
$ErrorActionPreference = $previousErrorActionPreference
if ($pythonExitCode -ne 0 -or $pythonVersion -notmatch '^Python 3\.11\.') {
    throw 'Python 3.11.x is required. Install it and rerun this preflight.'
}

Write-Host (& flutter --version | Select-Object -First 1)
Write-Host (& dart --version 2>&1)
Write-Host $pythonVersion
$javaVersion = (& cmd.exe /d /c 'java -version 2>&1' |
        Select-Object -First 1 |
        Out-String).Trim()
Write-Host $javaVersion
Write-Host (& adb version | Select-Object -First 1)
Write-Host 'Toolchain preflight passed.'
