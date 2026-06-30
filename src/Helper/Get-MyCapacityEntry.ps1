# Helper: get current sprint + my capacity entry via REST
function Get-MyCapacityEntry {
    param(
        [string]$Org = $AzureDevOpsConfig.Org,
        [string]$Project = $AzureDevOpsConfig.Project,
        [string]$Team = $AzureDevOpsConfig.Team
    )
    $sprint = Invoke-AzJson -Action "Getting current sprint for team '$Team'" -Command {
        az boards iteration team list --team $Team --timeframe current `
            --organization $Org --project $Project -o json
    } | Select-Object -First 1
    if (-not $sprint) { Write-Error "Could not determine current sprint."; return $null }

    $teamEncoded = [Uri]::EscapeDataString($Team)
    $url = "$Org/$Project/$teamEncoded/_apis/work/teamsettings/iterations/$($sprint.id)/capacities?api-version=7.1"
    $token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($AzureDevOpsConfig.PAT)"))
    $capacities = Invoke-RestMethod -Uri $url -Headers @{ Authorization = "Basic $token" } -Method GET

    $me = $capacities.teamMembers | Where-Object { $_.teamMember.uniqueName -eq $AzureDevOpsConfig.Me } | Select-Object -First 1
    if (-not $me) { Write-Error "Could not find your capacity entry."; return $null }

    return @{ Sprint = $sprint; Me = $me; TeamEncoded = $teamEncoded; Org = $Org; Project = $Project; Token = $token }
}
