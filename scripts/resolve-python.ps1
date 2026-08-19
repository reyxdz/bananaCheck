function Resolve-Python311 {
    $candidates = @()

    if ($env:LocalAppData) {
        $candidates += [pscustomobject]@{
            Command = Join-Path $env:LocalAppData 'Programs\Python\Python311\python.exe'
            Prefix = @()
        }
    }

    if (Get-Command py -ErrorAction SilentlyContinue) {
        $candidates += [pscustomobject]@{
            Command = 'py'
            Prefix = @('-3.11')
        }
    }

    if (Get-Command python3.11 -ErrorAction SilentlyContinue) {
        $candidates += [pscustomobject]@{
            Command = 'python3.11'
            Prefix = @()
        }
    }

    foreach ($candidate in $candidates) {
        if ($candidate.Command -match '[\\/]' -and -not (Test-Path $candidate.Command)) {
            continue
        }

        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $version = (& $candidate.Command @($candidate.Prefix) --version 2>&1 |
                    Out-String).Trim()
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        if ($exitCode -eq 0 -and $version -match '^Python 3\.11\.') {
            return [pscustomobject]@{
                Command = $candidate.Command
                Prefix = $candidate.Prefix
                Version = $version
            }
        }
    }

    throw 'Python 3.11.x is required. Install it and rerun this command.'
}
