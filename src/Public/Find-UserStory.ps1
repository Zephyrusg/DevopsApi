function Find-UserStory {
    <#
    .SYNOPSIS
        Searches the backlog for User Stories whose title contains the given keyword(s).
    .DESCRIPTION
        Runs a WIQL query against all active (non-closed, non-removed) User Stories in the project and filters
        by a case-insensitive title match. Returns matching stories with their ID, state,
        assigned-to and tags. Use -IncludeClosed to also search closed stories.
    .PARAMETER Query
        One or more words to search for in the story title (case-insensitive).
    .PARAMETER IncludeClosed
        When specified, also searches stories in a Closed state.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .PARAMETER Project
        Azure DevOps project name. Defaults to the active config.
    .EXAMPLE
        Find-UserStory -Query "login page"
    .EXAMPLE
        Find-UserStory -Query "reporting" -IncludeClosed
    #>
    param(
        [Parameter(Mandatory)][string]$Query,
        [switch]$IncludeClosed,
        [string]$Org = $AzureDevOpsConfig.Org,
        [string]$Project = $AzureDevOpsConfig.Project
    )

    $stateFilter = if ($IncludeClosed) { "AND [System.State] <> 'Removed'" } else { "AND [System.State] <> 'Closed' AND [System.State] <> 'Removed'" }
    $wiql = "SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo], [System.Tags] FROM WorkItems WHERE [System.TeamProject] = '$Project' AND [System.WorkItemType] = 'User Story' $stateFilter ORDER BY [System.ChangedDate] DESC"

    $stories = Invoke-AzJson -Action "Finding User Stories matching '$Query'" -Command {
        az boards query --wiql $wiql `
            --organization $Org --project $Project -o json
    }

    if (-not $stories -or $stories.Count -eq 0) {
        Write-Host "No User Stories found in project." -ForegroundColor Yellow
        return
    }

    $matchedStories = $stories | Where-Object { $_.fields.'System.Title' -like "*$Query*" }

    if (-not $matchedStories -or @($matchedStories).Count -eq 0) {
        Write-Host "No User Stories found matching '$Query'." -ForegroundColor Yellow
        return
    }

    Write-Host "`nFound $(@($matchedStories).Count) story/stories matching '$Query':`n" -ForegroundColor Cyan
    foreach ($s in $matchedStories) {
        $id = $s.id
        $title = $s.fields.'System.Title'
        $state = $s.fields.'System.State'
        $assigned = $s.fields.'System.AssignedTo'
        $assignedName = if ($assigned -and $assigned.displayName) { $assigned.displayName } elseif ($assigned) { $assigned } else { $null }
        $tags = $s.fields.'System.Tags'
        $tagStr = if ($tags) { "  [Tags: $tags]" } else { "" }
        $asgStr = if ($assignedName) { "  Assigned: $assignedName" } else { "  Unassigned" }
        Write-Host ("[US {0,6}] {1}" -f $id, $title) -ForegroundColor Green
        Write-Host ("           State: {0,-15}{1}{2}" -f $state, $asgStr, $tagStr) -ForegroundColor DarkGray
    }
    Write-Host ""
}
