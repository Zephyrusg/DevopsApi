function Get-MySprintItems {
    <#
    .SYNOPSIS
        Lists your User Stories for the current sprint.
    .DESCRIPTION
        Queries Azure DevOps for User Stories assigned to you in the current sprint iteration.
        With IncludeUnassigned it also includes unassigned User Stories and Bugs. Then for
        each item it fetches child Tasks and displays state, original estimate and remaining work.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .PARAMETER Project
        Azure DevOps project name. Defaults to the active config.
    .PARAMETER Team
        Team name used to resolve the current sprint. Defaults to the active config.
    .PARAMETER IncludeUnassigned
        Includes unassigned User Stories and Bugs in the current sprint.
    .EXAMPLE
        Get-MySprintItems
    #>
    param(
        [string]$Org = $AzureDevOpsConfig.Org,
        [string]$Project = $AzureDevOpsConfig.Project,
        [string]$Team = $AzureDevOpsConfig.Team,
        [switch]$IncludeUnassigned
    )
    $org = $Org
    $project = $Project
    $team = $Team

    $sprint = Invoke-AzJson -Action "Getting current sprint for team '$team'" -Command {
        az boards iteration team list --team $team --timeframe current `
            --organization $org --project $project -o json
    } | Select-Object -First 1
    if (-not $sprint) { Write-Error "Could not determine current sprint."; return }

    Write-Host "`nCurrent sprint: $($sprint.path)" -ForegroundColor Cyan

    $workItemFilter = if ($IncludeUnassigned) {
        "(([System.WorkItemType] = 'User Story' AND [System.AssignedTo] = @me) OR ([System.WorkItemType] IN ('User Story', 'Bug') AND [System.AssignedTo] = ''))"
    }
    else {
        "([System.WorkItemType] = 'User Story' AND [System.AssignedTo] = @me)"
    }

    # Get my User Stories, optionally including unassigned User Stories and Bugs in this sprint
    $workItems = Invoke-AzJson -Action "Getting sprint work items for '$($sprint.path)'" -AllowEmpty -Command {
        az boards query --wiql "SELECT [System.Id], [System.Title], [System.State], [System.WorkItemType], [System.AssignedTo], [System.Tags] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.IterationPath] = '$($sprint.path)' AND [System.State] <> 'Closed' AND [System.State] <> 'Removed' AND $workItemFilter ORDER BY [System.WorkItemType], [System.Id]" `
            --organization $org --project $project -o json
    }

    if (-not $workItems -or $workItems.Count -eq 0) {
        $doneMessage = if ($IncludeUnassigned) { "No more extra unassigned work for this sprint." } else { "All work is done for this sprint." }
        Write-Host $doneMessage -ForegroundColor Green
        return
    }

    foreach ($workItem in $workItems) {
        $id = $workItem.id
        $title = $workItem.fields.'System.Title'
        $state = $workItem.fields.'System.State'
        $type = $workItem.fields.'System.WorkItemType'
        $assigned = $workItem.fields.'System.AssignedTo'
        $assignedName = if ($assigned -and $assigned.displayName) { $assigned.displayName } elseif ($assigned) { $assigned } else { "Unassigned" }
        $tags = $workItem.fields.'System.Tags'
        $typeLabel = if ($type -eq 'Bug') { 'Bug' } else { 'US' }
        $tagStr = if ($tags) { "  [Tags: $tags]" } else { "" }
        Write-Host "`n[$typeLabel $id] $title  ($state)  Assigned: $assignedName$tagStr" -ForegroundColor Green

        # Get child Tasks
        $tasks = Invoke-AzJson -Action "Getting Tasks for $type $id" -AllowEmpty -Command {
            az boards query --wiql "SELECT [System.Id], [System.Title], [System.State], [System.Tags], [Microsoft.VSTS.Scheduling.OriginalEstimate], [Microsoft.VSTS.Scheduling.RemainingWork] FROM WorkItems WHERE [System.WorkItemType] = 'Task' AND [System.Parent] = $id AND [System.TeamProject] = '$project'" `
                --organization $org --project $project -o json
        }

        if (-not $tasks -or $tasks.Count -eq 0) {
            Write-Host "  (no tasks)" -ForegroundColor DarkGray
        }
        else {
            $tasks | ForEach-Object {
                $t = $_
                $tid = $t.id
                $ttitle = $t.fields.'System.Title'
                $tstate = $t.fields.'System.State'
                $estimated = $t.fields.'Microsoft.VSTS.Scheduling.OriginalEstimate'
                $remaining = $t.fields.'Microsoft.VSTS.Scheduling.RemainingWork'
                $ttags = $t.fields.'System.Tags'
                $estStr = if ($null -ne $estimated) { "${estimated}h" } else { "  -  " }
                $remStr = if ($null -ne $remaining) { "${remaining}h" } else { "  -  " }
                $ttagStr = if ($ttags) { "  [Tags: $ttags]" } else { "" }
                Write-Host ("  [Task {0}] {1,-55} State: {2,-10}  Est: {3,6}  Rem: {4,6}{5}" -f $tid, $ttitle, $tstate, $estStr, $remStr, $ttagStr)
            }
        }
    }
    Write-Host ""
}
