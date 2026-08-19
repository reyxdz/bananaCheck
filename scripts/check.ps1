$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [Parameter(Mandatory = $true)][string]$Description
    )

    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

function Require-File {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Required file '$Path' is missing. Run scripts\setup.cmd first."
    }
}

$mlPython = Join-Path $repoRoot 'ml\.venv\Scripts\python.exe'
$backendPython = Join-Path $repoRoot 'backend\.venv\Scripts\python.exe'
Require-File $mlPython
Require-File $backendPython

Push-Location (Join-Path $repoRoot 'app')
try {
    Invoke-Checked -FilePath 'dart' `
        -ArgumentList @('format', '--output=none', '--set-exit-if-changed', 'lib', 'test') `
        -Description 'Flutter formatting check'
    Invoke-Checked -FilePath 'flutter' -ArgumentList @('analyze') `
        -Description 'Flutter static analysis'
    Invoke-Checked -FilePath 'flutter' -ArgumentList @('test', '--coverage') `
        -Description 'Flutter tests'
}
finally {
    Pop-Location
}

Push-Location (Join-Path $repoRoot 'ml')
try {
    Invoke-Checked -FilePath $mlPython -ArgumentList @('-m', 'ruff', 'check', '.') `
        -Description 'ML linting'
    Invoke-Checked -FilePath $mlPython -ArgumentList @('-m', 'pytest', '-c', 'pytest.ini') `
        -Description 'ML tests'
}
finally {
    Pop-Location
}

Push-Location (Join-Path $repoRoot 'backend')
try {
    Invoke-Checked -FilePath $backendPython -ArgumentList @('-m', 'ruff', 'check', '.') `
        -Description 'Backend linting'
    Invoke-Checked -FilePath $backendPython -ArgumentList @('-m', 'pytest', '-c', 'pytest.ini') `
        -Description 'Backend tests'
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host 'All local checks passed.'
