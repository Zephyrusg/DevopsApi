function Close-UserStory {
    <#
    .SYNOPSIS
        Closes a User Story, auto-closing any open child Tasks first.
    .DESCRIPTION
        Queries all child Tasks that are not yet Closed and calls Close-Task on each,
        then sets the User Story state to Closed and posts the provided closing notes
        as a discussion comment.
    .PARAMETER StoryId
        The work item ID of the User Story to close.
    .PARAMETER ClosingNotes
        Text to post as a discussion comment on the User Story when closing.
    .EXAMPLE
        Close-UserStory -StoryId 4800 -ClosingNotes "Implemented and tested. Deployed to ACC."
    #>
    param(
        [Parameter(Mandatory)][int]$StoryId,
        [Parameter(Mandatory)][string]$ClosingNotes
    )
    # Close any child tasks that are not yet closed
    $tasks = az boards query --wiql "SELECT [System.Id], [System.State] FROM WorkItems WHERE [System.WorkItemType] = 'Task' AND [System.Parent] = $StoryId AND [System.State] <> 'Closed' AND [System.TeamProject] = '$($AzureDevOpsConfig.Project)'" `
        --organization $AzureDevOpsConfig.Org -o json 2>&1 | ConvertFrom-Json
    foreach ($task in $tasks) {
        Close-Task -TaskId $task.id
    }

    # Close the User Story with closing notes
    $result = az boards work-item update --id $StoryId `
        --state "Closed" `
        --discussion $ClosingNotes `
        --organization $AzureDevOpsConfig.Org -o json 2>&1 | ConvertFrom-Json
    $state = $result.fields.'System.State'
    Write-Host "User Story $StoryId closed. State: $state" -ForegroundColor Green
    Write-Host "Closing notes: $ClosingNotes" -ForegroundColor DarkGray
}
