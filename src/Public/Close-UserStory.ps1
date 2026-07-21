function Close-UserStory {
    <#
    .SYNOPSIS
        Closes a User Story, auto-closing any open child Tasks first.
    .DESCRIPTION
        Queries all child Tasks that are not yet Closed and calls Close-Task on each,
        then sets the User Story state to Closed and fills the close notes field when provided.
    .PARAMETER StoryId
        The work item ID of the User Story to close.
    .PARAMETER ClosingNotes
        Optional text to set in the User Story's close notes field when closing.
    .PARAMETER CloseNotesField
        Reference name of the Azure DevOps close notes field.
    .EXAMPLE
        Close-UserStory -StoryId 4800 -ClosingNotes "Implemented and tested. Deployed to ACC."
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$StoryId,
        [string]$ClosingNotes,
        [string]$CloseNotesField = "Custom.CloseNotes"
    )
    $hasClosingNotes = $PSBoundParameters.ContainsKey('ClosingNotes')

    $story = Invoke-AzJson -Action "Getting User Story $StoryId" -Command {
        az boards work-item show --id $StoryId `
            --organization $AzureDevOpsConfig.Org -o json
    }

    $workItemType = $story.fields.'System.WorkItemType'
    if ($workItemType -ne 'User Story') {
        $parentHint = ""
        if ($story.fields.'System.Parent') {
            $parentHint = " Parent work item: $($story.fields.'System.Parent')."
        }

        Write-Error "Work item $StoryId is '$workItemType', not 'User Story'.$parentHint"
        return
    }

    # Close any child tasks that are not yet closed
    $tasks = Invoke-AzJson -Action "Querying child tasks for User Story $StoryId" -AllowEmpty -Command {
        az boards query --wiql "SELECT [System.Id], [System.State] FROM WorkItems WHERE [System.WorkItemType] = 'Task' AND [System.Parent] = $StoryId AND [System.State] <> 'Closed' AND [System.TeamProject] = '$($AzureDevOpsConfig.Project)'" `
            --organization $AzureDevOpsConfig.Org -o json
    }
    $tasks = @($tasks | Where-Object { $_ -and $_.id })
    foreach ($task in $tasks) {
        Close-Task -TaskId $task.id
    }

    # Close the User Story with closing notes
    $fields = @("System.State=Closed")
    if ($hasClosingNotes) {
        $fields += "$CloseNotesField=$ClosingNotes"
    }

    $result = Invoke-AzJson -Action "Closing User Story $StoryId" -Command {
        az boards work-item update --id $StoryId `
            --fields $fields `
            --organization $AzureDevOpsConfig.Org -o json
    }
    $state = $result.fields.'System.State'
    Write-Host "User Story $StoryId closed. State: $state" -ForegroundColor Green
    if ($hasClosingNotes) {
        Write-Host "Closing notes: $ClosingNotes" -ForegroundColor DarkGray
    }
}
