$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'resolve-python.ps1')

$repoRoot = Split-Path -Parent $PSScriptRoot
$python = Resolve-Python311

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

function Initialize-PythonWorkspace {
    param([Parameter(Mandatory = $true)][string]$Workspace)

    $workspacePath = Join-Path $repoRoot $Workspace
    $venvPath = Join-Path $workspacePath '.venv'
    $venvPython = Join-Path $venvPath 'Scripts\python.exe'

    if (-not (Test-Path $venvPython)) {
        Write-Host "Creating $Workspace Python 3.11 environment..."
        Invoke-Checked -FilePath $python.Command `
            -ArgumentList ($python.Prefix + @('-m', 'venv', $venvPath)) `
            -Description "Creating the $Workspace virtual environment"
    }

    Invoke-Checked -FilePath $venvPython `
        -ArgumentList @('-m', 'pip', 'install', '--upgrade', 'pip') `
        -Description "Upgrading pip for $Workspace"
    Invoke-Checked -FilePath $venvPython `
        -ArgumentList @('-m', 'pip', 'install', '-r', (Join-Path $workspacePath 'requirements-dev.txt')) `
        -Description "Installing $Workspace dependencies"
}

& (Join-Path $PSScriptRoot 'preflight.ps1')

Push-Location (Join-Path $repoRoot 'app')
try {
    Invoke-Checked -FilePath 'flutter' -ArgumentList @('pub', 'get') `
        -Description 'Resolving Flutter dependencies'
}
finally {
    Pop-Location
}

Initialize-PythonWorkspace -Workspace 'ml'
Initialize-PythonWorkspace -Workspace 'backend'

Write-Host ''
Write-Host 'Local setup is ready.'
Write-Host 'Run scripts\check.cmd to verify the full workspace.'
