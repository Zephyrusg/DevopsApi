function Close-Bug {
    <#
    .SYNOPSIS
        Closes a Bug, optionally adding a discussion comment.
    .DESCRIPTION
        Closes any open child Tasks first, then sets the Bug state to Closed.
        If the Bug itself has RemainingWork, that field is cleared while CompletedWork is left as-is.
        Bugs do not use closing notes; pass Discussion to add a normal discussion comment.
    .PARAMETER BugId
        The work item ID of the Bug to close.
    .PARAMETER Discussion
        Optional text to add to the Bug discussion when closing.
    .EXAMPLE
        Close-Bug -BugId 29324
    .EXAMPLE
        Close-Bug -BugId 29324 -Discussion "Pipeline fixed and tested."
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Alias('Id')][int]$BugId,
        [string]$Discussion
    )

    $bug = Invoke-AzJson -Action "Getting Bug $BugId" -Command {
        az boards work-item show --id $BugId `
            --organization $AzureDevOpsConfig.Org -o json
    }

    $workItemType = $bug.fields.'System.WorkItemType'
    if ($workItemType -ne 'Bug') {
        Write-Error "Work item $BugId is '$workItemType', not 'Bug'."
        return
    }

    $remaining = if ($null -ne $bug.fields.'Microsoft.VSTS.Scheduling.RemainingWork') { $bug.fields.'Microsoft.VSTS.Scheduling.RemainingWork' } else { $null }
    $completed = if ($null -ne $bug.fields.'Microsoft.VSTS.Scheduling.CompletedWork') { $bug.fields.'Microsoft.VSTS.Scheduling.CompletedWork' } else { 0 }

    $tasks = Invoke-AzJson -Action "Querying child tasks for Bug $BugId" -AllowEmpty -Command {
        az boards query --wiql "SELECT [System.Id], [System.State] FROM WorkItems WHERE [System.WorkItemType] = 'Task' AND [System.Parent] = $BugId AND [System.State] <> 'Closed' AND [System.TeamProject] = '$($AzureDevOpsConfig.Project)'" `
            --organization $AzureDevOpsConfig.Org --project $AzureDevOpsConfig.Project -o json
    }

    $tasks = @($tasks | Where-Object { $_ -and $_.id })
    foreach ($task in $tasks) {
        Close-Task -TaskId $task.id
    }

    $fields = @("System.State=Closed")
    if ($null -ne $remaining) {
        $fields += "Microsoft.VSTS.Scheduling.RemainingWork="
    }

    $result = Invoke-AzJson -Action "Closing Bug $BugId" -Command {
        az boards work-item update --id $BugId `
            --fields $fields `
            --organization $AzureDevOpsConfig.Org -o json
    }

    if (-not [string]::IsNullOrWhiteSpace($Discussion)) {
        $token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($AzureDevOpsConfig.PAT)"))
        $headers = @{ Authorization = "Basic $token" }
        $commentsUrl = "$($AzureDevOpsConfig.Org)/$($AzureDevOpsConfig.Project)/_apis/wit/workItems/$BugId/comments?api-version=7.1-preview"
        $body = @{ text = $Discussion } | ConvertTo-Json

        Invoke-RestMethod -Uri $commentsUrl -Headers $headers -Method POST -Body $body -ContentType 'application/json' | Out-Null
    }

    $state = $result.fields.'System.State'
    $remainingText = if ($null -ne $remaining) { "  |  Remaining $remaining h cleared" } else { "" }
    Write-Host ("Bug {0} closed. State: {1}  |  Spent: {2} h{3}" -f $BugId, $state, $completed, $remainingText) -ForegroundColor Green
    if (-not [string]::IsNullOrWhiteSpace($Discussion)) {
        Write-Host "Discussion added: $Discussion" -ForegroundColor DarkGray
    }
}
