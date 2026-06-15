function Set-MySprintCapacity {
    <#
    .SYNOPSIS
        Sets your hours-per-day capacity and activity for the current sprint.
    .DESCRIPTION
        Updates your capacity entry in Azure DevOps for the active sprint via the REST API.
        Replaces the existing activity list with the single activity provided.
    .PARAMETER HoursPerDay
        Number of hours per day you are available in this sprint.
    .PARAMETER Activity
        Activity name to assign the capacity to. Defaults to "Unassigned".
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .PARAMETER Project
        Azure DevOps project name. Defaults to the active config.
    .PARAMETER Team
        Team name. Defaults to the active config.
    .EXAMPLE
        Set-MySprintCapacity -HoursPerDay 6
    .EXAMPLE
        Set-MySprintCapacity -HoursPerDay 7 -Activity "Development"
    #>
    param(
        [Parameter(Mandatory)][double]$HoursPerDay,
        [string]$Activity = "Unassigned",
        [string]$Org = $AzureDevOpsConfig.Org,
        [string]$Project = $AzureDevOpsConfig.Project,
        [string]$Team = $AzureDevOpsConfig.Team
    )
    $ctx = Get-MyCapacityEntry -Org $Org -Project $Project -Team $Team
    if (-not $ctx) { return }

    $patchUrl = "$($ctx.Org)/$($ctx.Project)/$($ctx.TeamEncoded)/_apis/work/teamsettings/iterations/$($ctx.Sprint.id)/capacities/$($ctx.Me.teamMember.id)?api-version=7.1"
    $body = @{ activities = @(@{ capacityPerDay = $HoursPerDay; name = $Activity }) } | ConvertTo-Json -Compress
    Invoke-RestMethod -Uri $patchUrl -Headers @{ Authorization = "Basic $($ctx.Token)"; 'Content-Type' = 'application/json' } -Method PATCH -Body $body | Out-Null
    Write-Host "Capacity set to $HoursPerDay h/day ($Activity) for $($ctx.Sprint.path)" -ForegroundColor Green
}
