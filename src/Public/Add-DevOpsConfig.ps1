function Add-DevOpsConfig {
    <#
    .SYNOPSIS
        Adds or updates an Azure DevOps connection config and persists it to ~/.devops-configs.json.
    .DESCRIPTION
        Stores the org URL, project, team, user e-mail and PAT for a named config entry.
        The entry is written to the JSON config store immediately and loaded into the current session.
        Use Set-DevOpsConfig to activate a stored config.
    .PARAMETER Name
        Unique identifier for this config, e.g. "MYORG-MYPROJECT".
    .PARAMETER Org
        Azure DevOps organisation URL, e.g. "https://dev.azure.com/myorg".
    .PARAMETER Project
        Name of the Azure DevOps project.
    .PARAMETER Team
        Name of the team inside the project.
    .PARAMETER Me
        Your Azure DevOps account e-mail address. Used to find your capacity entry.
    .PARAMETER PAT
        Personal Access Token used to authenticate CLI and REST calls.
    .EXAMPLE
        Add-DevOpsConfig -Name "MYORG-MYPROJECT" -Org "https://dev.azure.com/myorg" -Project "MyProject" -Team "My Team" -Me "me@example.com" -PAT "my-pat"
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Org,
        [Parameter(Mandatory)][string]$Project,
        [Parameter(Mandatory)][string]$Team,
        [Parameter(Mandatory)][string]$Me,
        [Parameter(Mandatory)][string]$PAT
    )

    $entry = @{ Org = $Org; Project = $Project; Team = $Team; Me = $Me; PAT = $PAT }

    # Update session
    if (-not $global:AzureDevOpsConfigs) { $global:AzureDevOpsConfigs = @{} }
    $global:AzureDevOpsConfigs[$Name] = $entry

    # Persist to JSON store
    $store = Get-DevOpsConfigStore
    $store[$Name] = $entry
    Save-DevOpsConfigStore -Store $store

    Write-Host "Config '$Name' saved to $(Get-DevOpsConfigStorePath)" -ForegroundColor Green
}
