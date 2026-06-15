function Connect-AzureDevOps {
    <#
    .SYNOPSIS
        Authenticates the Azure DevOps CLI using the PAT from the active config.
    .DESCRIPTION
        Pipes the PAT stored in the active config to `az devops login`.
        Called automatically on profile load. Run manually after switching configs with Set-DevOpsConfig.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .EXAMPLE
        Connect-AzureDevOps
    .EXAMPLE
        Connect-AzureDevOps -Org "https://dev.azure.com/myorg"
    #>
    param([string]$Org = $AzureDevOpsConfig.Org)
    $pat = $AzureDevOpsConfig.PAT
    if (-not $pat) { Write-Error "No PAT found in active config. Add a 'PAT' entry to your config in the profile."; return }
    $pat | az devops login --organization $Org
    Write-Host "Logged in to $Org" -ForegroundColor Green
}
