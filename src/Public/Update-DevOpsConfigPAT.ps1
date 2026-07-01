function Update-DevOpsConfigPAT {
    <#
    .SYNOPSIS
        Updates the PAT for an existing Azure DevOps config entry.
    .DESCRIPTION
        Loads the config store, updates only the PAT field for the named entry,
        saves it back to ~/.devops-configs.json and refreshes the active session
        config if the updated entry is currently active.
    .PARAMETER Name
        Name of the config entry to update. Defaults to the currently active config.
    .PARAMETER PAT
        The new Personal Access Token.
    .EXAMPLE
        Set-DevOpsConfigPAT -PAT "my-new-pat"
    .EXAMPLE
        Set-DevOpsConfigPAT -Name "MYORG-MYPROJECT" -PAT "my-new-pat"
    #>
    param(
        [string]$Name = $global:AzureDevOpsActiveConfig,
        [Parameter(Mandatory)][string]$PAT
    )

    if (-not $Name) {
        Write-Error "No config name specified and no active config set. Use Set-DevOpsConfig first or pass -Name."
        return
    }

    $store = Get-DevOpsConfigStore
    if (-not $store.ContainsKey($Name)) {
        Write-Error "Config '$Name' not found. Available: $($store.Keys -join ', ')"
        return
    }

    $store[$Name].PAT = $PAT
    Save-DevOpsConfigStore -Store $store

    # Refresh the active session config if this entry is currently active
    if ($global:AzureDevOpsActiveConfig -eq $Name) {
        $global:AzureDevOpsConfig.PAT = $PAT
    }

    Write-Host "PAT updated for config '$Name'." -ForegroundColor Green
}
