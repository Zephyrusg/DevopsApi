function Invoke-AzJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock]$Command,
        [Parameter(Mandatory)][string]$Action,
        [switch]$AllowEmpty
    )

    # A caller's WhatIf must not disable stderr redirection or temp-file cleanup.
    $WhatIfPreference = $false
    $errorFile = [System.IO.Path]::GetTempFileName()
    try {
        $output = & $Command 2> $errorFile
        $exitCode = $LASTEXITCODE
        $errorText = Get-Content -LiteralPath $errorFile -Raw
        $errorText = if ($null -eq $errorText) { "" } else { $errorText.Trim() }

        if ($exitCode -ne 0) {
            throw "$Action failed.`n$errorText"
        }

        $json = ($output | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($json)) {
            if ($AllowEmpty) {
                return $null
            }

            throw "$Action returned no JSON output.`n$errorText"
        }

        try {
            return $json | ConvertFrom-Json
        }
        catch {
            throw "$Action returned invalid JSON.`n$json"
        }
    }
    finally {
        Remove-Item -LiteralPath $errorFile -Force -ErrorAction SilentlyContinue -WhatIf:$false
    }
}
