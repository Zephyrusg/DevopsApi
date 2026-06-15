function Set-DevOpsConfig {
    <#
    .SYNOPSIS
        Switches the active Azure DevOps connection config for the current session.
    .DESCRIPTION
        Sets the global $AzureDevOpsConfig variable to the named entry from the
        loaded config store. All other functions use this active config by default.
        Run Connect-AzureDevOps afterwards to re-authenticate the CLI if the org changed.
    .PARAMETER Name
        Name of the config to activate, as stored in ~/.devops-configs.json.
    .EXAMPLE
        Set-DevOpsConfig -Name "MYORG-MYPROJECT"
    #>
    param([Parameter(Mandatory)][string]$Name)
    if (-not $AzureDevOpsConfigs.ContainsKey($Name)) {
        Write-Error "Config '$Name' not found. Available: $($AzureDevOpsConfigs.Keys -join ', ')"
        return
    }
    $global:AzureDevOpsConfig = $AzureDevOpsConfigs[$Name]
    $global:AzureDevOpsActiveConfig = $Name
    Write-Host "Active config: [$Name]  $($AzureDevOpsConfig.Org) / $($AzureDevOpsConfig.Project)" -ForegroundColor Cyan
}
