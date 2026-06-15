function Get-MySprintCapacity {
    <#
    .SYNOPSIS
        Shows your capacity settings for the current sprint.
    .DESCRIPTION
        Displays your hours-per-day per activity and any personal days off
        registered in the Azure DevOps sprint capacity for the current iteration.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .PARAMETER Project
        Azure DevOps project name. Defaults to the active config.
    .PARAMETER Team
        Team name. Defaults to the active config.
    .EXAMPLE
        Get-MySprintCapacity
    #>
    param(
        [string]$Org = $AzureDevOpsConfig.Org,
        [string]$Project = $AzureDevOpsConfig.Project,
        [string]$Team = $AzureDevOpsConfig.Team
    )
    $ctx = Get-MyCapacityEntry -Org $Org -Project $Project -Team $Team
    if (-not $ctx) { return }

    $me = $ctx.Me
    $startDate = ([datetime]$ctx.Sprint.attributes.startDate).ToString("yyyy-MM-dd")
    $endDate = ([datetime]$ctx.Sprint.attributes.finishDate).ToString("yyyy-MM-dd")
    Write-Host "`nCapacity for sprint: $($ctx.Sprint.path)  ($startDate → $endDate)" -ForegroundColor Cyan
    Write-Host "  Member:     $($me.teamMember.displayName)" -ForegroundColor Green

    if ($me.activities) {
        $me.activities | ForEach-Object {
            $actName = if ($_.name) { $_.name } else { "(none)" }
            Write-Host ("  Activity:   {0,-25} {1} h/day" -f $actName, $_.capacityPerDay)
        }
    }
    else {
        Write-Host "  Activity:   (none set)"
    }

    if ($me.daysOff -and $me.daysOff.Count -gt 0) {
        Write-Host "  Days off:" -ForegroundColor Yellow
        $me.daysOff | ForEach-Object {
            Write-Host "    $(([datetime]$_.start).ToString('yyyy-MM-dd'))  →  $(([datetime]$_.end).ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  Days off:   (none)"
    }
    Write-Host ""
}
