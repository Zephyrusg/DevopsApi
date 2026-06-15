function Get-Feature {
    <#
    .SYNOPSIS
        Returns a Feature as a PowerShell object including child User Stories and related items.
    .DESCRIPTION
        Fetches the work item fields for the given Feature ID and returns a PSCustomObject
        with all feature properties (title, state, assigned-to, iteration, area, tags, priority,
        description, acceptance criteria) plus a UserStories array, Discussion array and
        RelatedItems array. Pipe to Format-List or select individual properties.
    .PARAMETER FeatureId
        The work item ID of the Feature to retrieve.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .PARAMETER Project
        Azure DevOps project name. Defaults to the active config.
    .EXAMPLE
        Get-Feature -FeatureId 1234
    .EXAMPLE
        Get-Feature -FeatureId 1234 | Format-List
    .EXAMPLE
        (Get-Feature -FeatureId 1234).UserStories
    .EXAMPLE
        (Get-Feature -FeatureId 1234).RelatedItems
    #>
    param(
        [Parameter(Mandatory)][int]$FeatureId,
        [string]$Org     = $AzureDevOpsConfig.Org,
        [string]$Project = $AzureDevOpsConfig.Project
    )

    $item = az boards work-item show --id $FeatureId `
        --organization $Org -o json 2>&1 | ConvertFrom-Json

    if (-not $item) { Write-Error "Work item $FeatureId not found."; return }

    $f = $item.fields

    $assigned = $f.'System.AssignedTo'
    $assignedName = if ($assigned -and $assigned.displayName) { $assigned.displayName } elseif ($assigned) { $assigned } else { $null }

    # Child User Stories
    $storyItems = az boards query --wiql "SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo], [Microsoft.VSTS.Scheduling.StoryPoints] FROM WorkItems WHERE [System.WorkItemType] = 'User Story' AND [System.Parent] = $FeatureId AND [System.TeamProject] = '$Project'" `
        --organization $Org --project $Project -o json 2>&1 | ConvertFrom-Json

    $userStories = @()
    if ($storyItems) {
        $userStories = $storyItems | ForEach-Object {
            $sa = $_.fields.'System.AssignedTo'
            [PSCustomObject]@{
                Id          = $_.id
                Title       = $_.fields.'System.Title'
                State       = $_.fields.'System.State'
                AssignedTo  = if ($sa -and $sa.displayName) { $sa.displayName } elseif ($sa) { $sa } else { $null }
                StoryPoints = $_.fields.'Microsoft.VSTS.Scheduling.StoryPoints'
            }
        }
    }

    $token   = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($AzureDevOpsConfig.PAT)"))
    $headers = @{ Authorization = "Basic $token" }

    # Discussion
    $discussion = @()
    try {
        $commentsResponse = Invoke-RestMethod -Uri "$Org/$Project/_apis/wit/workItems/$FeatureId/comments?api-version=7.1-preview" -Headers $headers -Method GET
        $discussion = $commentsResponse.comments | ForEach-Object {
            [PSCustomObject]@{
                Author = $_.createdBy.displayName
                Date   = ([datetime]$_.createdDate).ToString('yyyy-MM-dd HH:mm')
                Text   = ($_.text -replace '<[^>]+>', '' -replace '&nbsp;', ' ').Trim()
            }
        }
    }
    catch {
        Write-Warning "Could not fetch discussion for work item $($FeatureId): $_"
    }

    # Related items
    $relatedItems = @()
    try {
        $relTypeMap = @{
            'System.LinkTypes.Hierarchy-Reverse' = 'Parent'
            'System.LinkTypes.Hierarchy-Forward' = 'Child'
            'System.LinkTypes.Related'           = 'Related'
            'System.LinkTypes.Duplicate-Forward' = 'Duplicate of'
            'System.LinkTypes.Duplicate-Reverse' = 'Duplicated by'
        }
        $wiDetail   = Invoke-RestMethod -Uri "$Org/$Project/_apis/wit/workItems/$($FeatureId)?`$expand=relations&api-version=7.1" -Headers $headers -Method GET
        $relations  = $wiDetail.relations | Where-Object { $_.url -match '/_apis/wit/workItems/(\d+)$' }
        if ($relations) {
            $relIds     = $relations | ForEach-Object { [regex]::Match($_.url, '/(\d+)$').Groups[1].Value }
            $batchResult = Invoke-RestMethod -Uri "$Org/_apis/wit/workItems?ids=$($relIds -join ',')&fields=System.Id,System.Title,System.State,System.WorkItemType&api-version=7.1" -Headers $headers -Method GET
            $batchMap   = @{}
            $batchResult.value | ForEach-Object { $batchMap["$($_.id)"] = $_ }

            $relatedItems = $relations | ForEach-Object {
                $relId = [regex]::Match($_.url, '/(\d+)$').Groups[1].Value
                $wi    = $batchMap[$relId]
                [PSCustomObject]@{
                    Relation = if ($relTypeMap[$_.rel]) { $relTypeMap[$_.rel] } else { $_.rel }
                    Id       = [int]$relId
                    Type     = $wi.fields.'System.WorkItemType'
                    Title    = $wi.fields.'System.Title'
                    State    = $wi.fields.'System.State'
                }
            }
        }
    }
    catch {
        Write-Warning "Could not fetch relations for work item $($FeatureId): $_"
    }

    [PSCustomObject]@{
        Id                 = $FeatureId
        Title              = $f.'System.Title'
        State              = $f.'System.State'
        AssignedTo         = $assignedName
        IterationPath      = $f.'System.IterationPath'
        AreaPath           = $f.'System.AreaPath'
        Tags               = $f.'System.Tags'
        Priority           = $f.'Microsoft.VSTS.Common.Priority'
        Description        = ($f.'System.Description' -replace '<[^>]+>', '' -replace '&nbsp;', ' ').Trim()
        AcceptanceCriteria = ($f.'Microsoft.VSTS.Common.AcceptanceCriteria' -replace '<[^>]+>', '' -replace '&nbsp;', ' ').Trim()
        UserStories        = $userStories
        Discussion         = $discussion
        RelatedItems       = $relatedItems
    }
}
