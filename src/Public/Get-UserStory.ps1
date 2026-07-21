function Get-UserStory {
    <#
    .SYNOPSIS
        Returns a User Story as a PowerShell object including all fields and child Tasks.
    .DESCRIPTION
        Fetches the work item fields for the given User Story ID and returns a PSCustomObject
        with all story properties (title, state, assigned-to, iteration, area, tags, priority,
        story points, description, acceptance criteria) plus a Tasks array, a Discussion array
        and a RelatedItems array (parent, related, duplicates etc.) each as a small object
        with Relation, Id, Type, Title and State.
    .PARAMETER StoryId
        The work item ID of the User Story to retrieve.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .PARAMETER Project
        Azure DevOps project name. Defaults to the active config.
    .EXAMPLE
        Get-UserStory -StoryId 4800
    .EXAMPLE
        Get-UserStory -StoryId 4800 | Format-List
    .EXAMPLE
        (Get-UserStory -StoryId 4800).Tasks
    .EXAMPLE
        (Get-UserStory -StoryId 4800).Discussion
    .EXAMPLE
        (Get-UserStory -StoryId 4800).RelatedItems
    #>
    param(
        [Parameter(Mandatory)][int]$StoryId,
        [string]$Org = $AzureDevOpsConfig.Org,
        [string]$Project = $AzureDevOpsConfig.Project
    )

    $item = Invoke-AzJson -Action "Getting User Story $StoryId" -Command {
        az boards work-item show --id $StoryId `
            --organization $Org -o json
    }

    if (-not $item) { Write-Error "Work item $StoryId not found."; return }

    $f = $item.fields

    $assigned = $f.'System.AssignedTo'
    $assignedName = if ($assigned -and $assigned.displayName) { $assigned.displayName } elseif ($assigned) { $assigned } else { $null }

    $taskItems = Invoke-AzJson -Action "Querying Tasks for User Story $StoryId" -AllowEmpty -Command {
        az boards query --wiql "SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo], [Microsoft.VSTS.Scheduling.OriginalEstimate], [Microsoft.VSTS.Scheduling.RemainingWork], [Microsoft.VSTS.Scheduling.CompletedWork] FROM WorkItems WHERE [System.WorkItemType] = 'Task' AND [System.Parent] = $StoryId AND [System.TeamProject] = '$Project'" `
            --organization $Org --project $Project -o json
    }

    $tasks = @()
    if ($taskItems) {
        $tasks = $taskItems | ForEach-Object {
            $ta = $_.fields.'System.AssignedTo'
            [PSCustomObject]@{
                Id               = $_.id
                Title            = $_.fields.'System.Title'
                State            = $_.fields.'System.State'
                AssignedTo       = if ($ta -and $ta.displayName) { $ta.displayName } elseif ($ta) { $ta } else { $null }
                OriginalEstimate = $_.fields.'Microsoft.VSTS.Scheduling.OriginalEstimate'
                RemainingWork    = $_.fields.'Microsoft.VSTS.Scheduling.RemainingWork'
                CompletedWork    = $_.fields.'Microsoft.VSTS.Scheduling.CompletedWork'
            }
        }
    }

    # Fetch discussion comments via REST API
    $token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($AzureDevOpsConfig.PAT)"))
    $headers = @{ Authorization = "Basic $token" }

    $commentsUrl = "$Org/$Project/_apis/wit/workItems/$StoryId/comments?api-version=7.1-preview"
    $discussion = @()
    try {
        $commentsResponse = Invoke-RestMethod -Uri $commentsUrl -Headers $headers -Method GET
        $discussion = $commentsResponse.comments | ForEach-Object {
            [PSCustomObject]@{
                Author = $_.createdBy.displayName
                Date   = ([datetime]$_.createdDate).ToString('yyyy-MM-dd HH:mm')
                Text   = ($_.text -replace '<[^>]+>', '' -replace '&nbsp;', ' ').Trim()
            }
        }
    }
    catch {
        Write-Warning "Could not fetch discussion for work item $($StoryId): $_"
    }

    # Fetch relations via REST (az work-item show doesn't include them)
    $relatedItems = @()
    try {
        $wiUrl = "$Org/$Project/_apis/wit/workItems/$($StoryId)?`$expand=relations&api-version=7.1"
        $wiDetail = Invoke-RestMethod -Uri $wiUrl -Headers $headers -Method GET
        if ($wiDetail.relations) {
            # Map relation type ref names to readable labels
            $relTypeMap = @{
                'System.LinkTypes.Hierarchy-Reverse' = 'Parent'
                'System.LinkTypes.Hierarchy-Forward' = 'Child'
                'System.LinkTypes.Related'           = 'Related'
                'System.LinkTypes.Duplicate-Forward' = 'Duplicate of'
                'System.LinkTypes.Duplicate-Reverse' = 'Duplicated by'
                'Microsoft.VSTS.Common.Affects-Forward'  = 'Affects'
                'Microsoft.VSTS.Common.Affects-Reverse'  = 'Affected by'
            }

            # Extract work item IDs from relation URLs (skip non-workitem relations like attachments)
            $relations = $wiDetail.relations | Where-Object { $_.url -match '/_apis/wit/workItems/(\d+)$' }
            if ($relations) {
                $relIds = $relations | ForEach-Object { [regex]::Match($_.url, '/(\d+)$').Groups[1].Value }
                $batchUrl = "$Org/_apis/wit/workItems?ids=$($relIds -join ',')&fields=System.Id,System.Title,System.State,System.WorkItemType&api-version=7.1"
                $batchResult = Invoke-RestMethod -Uri $batchUrl -Headers $headers -Method GET
                $batchMap = @{}
                $batchResult.value | ForEach-Object { $batchMap["$($_.id)"] = $_ }

                $relatedItems = $relations | ForEach-Object {
                    $relId = [regex]::Match($_.url, '/(\d+)$').Groups[1].Value
                    $wi = $batchMap[$relId]
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
    }
    catch {
        Write-Warning "Could not fetch relations for work item $($StoryId): $_"
    }

    [PSCustomObject]@{
        Id                 = $StoryId
        Title              = $f.'System.Title'
        State              = $f.'System.State'
        AssignedTo         = $assignedName
        IterationPath      = $f.'System.IterationPath'
        AreaPath           = $f.'System.AreaPath'
        Tags               = $f.'System.Tags'
        Priority           = $f.'Microsoft.VSTS.Common.Priority'
        StoryPoints        = $f.'Microsoft.VSTS.Scheduling.StoryPoints'
        Description        = ($f.'System.Description' -replace '<[^>]+>', '' -replace '&nbsp;', ' ').Trim()
        AcceptanceCriteria = ($f.'Microsoft.VSTS.Common.AcceptanceCriteria' -replace '<[^>]+>', '' -replace '&nbsp;', ' ').Trim()
        Tasks              = $tasks
        Discussion         = $discussion
        RelatedItems       = $relatedItems
    }
}
