function Close-Task {
    <#
    .SYNOPSIS
        Closes a Task, clearing remaining work without touching CompletedWork.
    .DESCRIPTION
        Sets the task state to Closed and clears RemainingWork.
        CompletedWork is left as-is, reflecting actual time spent.
        If you want to log additional time before closing, use Set-TaskRemainingHours first.
    .PARAMETER TaskId
        The work item ID of the Task to close.
    .EXAMPLE
        Close-Task -TaskId 4821
    #>
    param(
        [Parameter(Mandatory)][int]$TaskId
    )
    $item = Invoke-AzJson -Action "Getting Task $TaskId" -Command {
        az boards work-item show --id $TaskId `
            --organization $AzureDevOpsConfig.Org -o json
    }

    $workItemType = $item.fields.'System.WorkItemType'
    if ($workItemType -ne 'Task') {
        Write-Error "Work item $TaskId is '$workItemType', not 'Task'."
        return
    }

    $remaining = if ($null -ne $item.fields.'Microsoft.VSTS.Scheduling.RemainingWork') { $item.fields.'Microsoft.VSTS.Scheduling.RemainingWork' } else { 0 }
    $completed = if ($null -ne $item.fields.'Microsoft.VSTS.Scheduling.CompletedWork') { $item.fields.'Microsoft.VSTS.Scheduling.CompletedWork' } else { 0 }

    Invoke-AzJson -Action "Closing Task $TaskId" -Command {
        az boards work-item update --id $TaskId `
            --fields "System.State=Closed" `
            "Microsoft.VSTS.Scheduling.RemainingWork=" `
            --organization $AzureDevOpsConfig.Org -o json
    } | Out-Null
    Write-Host ("Task {0} closed  |  Spent: {1} h  |  Remaining {2} h cleared" -f $TaskId, $completed, $remaining) -ForegroundColor Green
}
