function Get-OpenUserStoriesByTag {
    <#
    .SYNOPSIS
        Lists all open User Stories in the project that contain a specific tag.
    .DESCRIPTION
        Queries Azure DevOps for User Stories that are not Closed or Removed and
        whose Tags field contains the given value. Useful for tracking stories by
        workflow tags such as "pre-refinement" or "blocked".
    .PARAMETER Tag
        Tag value to filter on. Defaults to "pre-refinement".
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .PARAMETER Project
        Azure DevOps project name. Defaults to the active config.
    .PARAMETER Team
        Team name. Defaults to the active config.
    .EXAMPLE
        Get-OpenUserStoriesByTag
    .EXAMPLE
        Get-OpenUserStoriesByTag -Tag "blocked"
    #>
    param(
        [string]$Tag = "pre-refinement",
        [string]$Org = $AzureDevOpsConfig.Org,
        [string]$Project = $AzureDevOpsConfig.Project,
        [string]$Team = $AzureDevOpsConfig.Team
    )
    $org = $Org
    $project = $Project
    $safeTag = $Tag -replace "'", "''"

    Write-Host "`nProject: $project" -ForegroundColor Cyan
    Write-Host "Tag filter: $Tag" -ForegroundColor Cyan

    $stories = az boards query --wiql "SELECT [System.Id], [System.Title], [System.State], [System.Tags] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.State] <> 'Closed' AND [System.State] <> 'Removed' AND [System.Tags] CONTAINS '$safeTag' ORDER BY [System.Id]" `
        --organization $org --project $project -o json 2>&1 | ConvertFrom-Json

    if (-not $stories -or $stories.Count -eq 0) {
        Write-Host "No open User Stories found with tag '$Tag'." -ForegroundColor Yellow
        return
    }

    foreach ($story in $stories) {
        $id = $story.id
        $title = $story.fields.'System.Title'
        $state = $story.fields.'System.State'
        $tags = $story.fields.'System.Tags'
        $tagStr = if ($tags) { "  [Tags: $tags]" } else { "" }
        Write-Host "[US $id] $title  ($state)$tagStr" -ForegroundColor Green
    }

    Write-Host ""
}
