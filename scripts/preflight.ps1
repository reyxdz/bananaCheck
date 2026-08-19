$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'resolve-python.ps1')

function Require-Command {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found on PATH. See README.md prerequisites."
    }
}

@('flutter', 'dart', 'java', 'adb') | ForEach-Object { Require-Command $_ }
$python = Resolve-Python311

Write-Host (& flutter --version | Select-Object -First 1)
Write-Host (& dart --version 2>&1)
Write-Host $python.Version
$javaVersion = (& cmd.exe /d /c 'java -version 2>&1' |
        Select-Object -First 1 |
        Out-String).Trim()
Write-Host $javaVersion
Write-Host (& adb version | Select-Object -First 1)
Write-Host 'Toolchain preflight passed.'
