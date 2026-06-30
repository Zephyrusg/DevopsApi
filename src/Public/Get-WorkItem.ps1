function Get-WorkItem {
    <#
    .SYNOPSIS
        Retrieves any Azure DevOps work item by ID, dispatching to the correct typed function.
    .DESCRIPTION
        Looks up the work item type for the given ID, then calls the appropriate function:
          - User Story  → Get-UserStory
          - Feature     → Get-Feature
        For all other types (Epic, Task, Bug, etc.) a generic PSCustomObject is returned
        with Id, Type, Title, State, AssignedTo, IterationPath, AreaPath, Tags and Description.
    .PARAMETER Id
        The work item ID to retrieve.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .PARAMETER Project
        Azure DevOps project name. Defaults to the active config.
    .EXAMPLE
        Get-WorkItem -Id 4800
    .EXAMPLE
        Get-WorkItem -Id 4800 | Format-List
    #>
    param(
        [Parameter(Mandatory)][int]$Id,
        [string]$Org     = $AzureDevOpsConfig.Org,
        [string]$Project = $AzureDevOpsConfig.Project
    )

    $item = Invoke-AzJson -Action "Getting Work Item $Id" -Command {
        az boards work-item show --id $Id `
            --organization $Org -o json
    }

    if (-not $item) { Write-Error "Work item $Id not found."; return }

    $type = $item.fields.'System.WorkItemType'

    switch ($type) {
        'User Story' { return Get-UserStory -StoryId $Id -Org $Org -Project $Project }
        'Feature'    { return Get-Feature   -FeatureId $Id -Org $Org -Project $Project }
        default {
            $assigned = $item.fields.'System.AssignedTo'
            [PSCustomObject]@{
                Id            = $Id
                Type          = $type
                Title         = $item.fields.'System.Title'
                State         = $item.fields.'System.State'
                AssignedTo    = if ($assigned -and $assigned.displayName) { $assigned.displayName } elseif ($assigned) { $assigned } else { $null }
                IterationPath = $item.fields.'System.IterationPath'
                AreaPath      = $item.fields.'System.AreaPath'
                Tags          = $item.fields.'System.Tags'
                Description   = ($item.fields.'System.Description' -replace '<[^>]+>', '' -replace '&nbsp;', ' ').Trim()
            }
        }
    }
}
