function Get-MySprintItems {
    <#
    .SYNOPSIS
        Lists your User Stories and their child Tasks for the current sprint.
    .DESCRIPTION
        Queries Azure DevOps for User Stories assigned to you in the current sprint iteration,
        then for each story fetches its child Tasks and displays state, original estimate
        and remaining work.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .PARAMETER Project
        Azure DevOps project name. Defaults to the active config.
    .PARAMETER Team
        Team name used to resolve the current sprint. Defaults to the active config.
    .EXAMPLE
        Get-MySprintItems
    #>
    param(
        [string]$Org = $AzureDevOpsConfig.Org,
        [string]$Project = $AzureDevOpsConfig.Project,
        [string]$Team = $AzureDevOpsConfig.Team
    )
    $org = $Org
    $project = $Project
    $team = $Team

    $sprint = az boards iteration team list --team $team --timeframe current `
        --organization $org --project $project -o json 2>&1 | ConvertFrom-Json | Select-Object -First 1
    if (-not $sprint) { Write-Error "Could not determine current sprint."; return }

    Write-Host "`nCurrent sprint: $($sprint.path)" -ForegroundColor Cyan

    # Get my User Stories in this sprint
    $stories = az boards query --wiql "SELECT [System.Id], [System.Title], [System.State], [System.Tags] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.AssignedTo] = @me AND [System.WorkItemType] = 'User Story' AND [System.IterationPath] = '$($sprint.path)' AND [System.State] <> 'Closed'" `
        --organization $org --project $project -o json 2>&1 | ConvertFrom-Json

    if (-not $stories -or $stories.Count -eq 0) { Write-Host "No active User Stories found." -ForegroundColor Yellow; return }

    foreach ($story in $stories) {
        $id = $story.id
        $title = $story.fields.'System.Title'
        $state = $story.fields.'System.State'
        $tags = $story.fields.'System.Tags'
        $tagStr = if ($tags) { "  [Tags: $tags]" } else { "" }
        Write-Host "`n[US $id] $title  ($state)$tagStr" -ForegroundColor Green

        # Get child Tasks
        $tasks = az boards query --wiql "SELECT [System.Id], [System.Title], [System.State], [System.Tags], [Microsoft.VSTS.Scheduling.OriginalEstimate], [Microsoft.VSTS.Scheduling.RemainingWork] FROM WorkItems WHERE [System.WorkItemType] = 'Task' AND [System.Parent] = $id AND [System.TeamProject] = '$project'" `
            --organization $org --project $project -o json 2>&1 | ConvertFrom-Json

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
