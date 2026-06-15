function Set-TaskRemainingHours {
    <#
    .SYNOPSIS
        Deducts hours from a Task's remaining work and adds them to CompletedWork.
    .DESCRIPTION
        Fetches the current remaining and completed work for the task, subtracts
        HoursToDeduct from remaining (minimum 0) and adds it to completed, then
        updates the work item. Useful for logging time spent at end of day.
    .PARAMETER TaskId
        The work item ID of the Task to update.
    .PARAMETER HoursToDeduct
        Number of hours to move from remaining to completed.
    .EXAMPLE
        Set-TaskRemainingHours -TaskId 4821 -HoursToDeduct 3
    #>
    param(
        [Parameter(Mandatory)][int]$TaskId,
        [Parameter(Mandatory)][double]$HoursToDeduct
    )
    $item = az boards work-item show --id $TaskId `
        --organization $AzureDevOpsConfig.Org -o json 2>&1 | ConvertFrom-Json
    $remaining = if ($null -ne $item.fields.'Microsoft.VSTS.Scheduling.RemainingWork') { $item.fields.'Microsoft.VSTS.Scheduling.RemainingWork' } else { 0 }
    $completed = if ($null -ne $item.fields.'Microsoft.VSTS.Scheduling.CompletedWork') { $item.fields.'Microsoft.VSTS.Scheduling.CompletedWork' } else { 0 }

    $newRemaining = $remaining - $HoursToDeduct
    if ($newRemaining -lt 0) {
        if ($remaining -eq 0) {
            Write-Host "Task $TaskId already at 0 h remaining — nothing to deduct." -ForegroundColor Yellow
            return
        }
        Write-Warning "Deducting $HoursToDeduct h would bring remaining below 0 (currently $remaining h). Setting remaining to 0."
        $newRemaining = 0
    }
    $newCompleted = $completed + $HoursToDeduct

    $result = az boards work-item update --id $TaskId `
        --fields "Microsoft.VSTS.Scheduling.RemainingWork=$newRemaining" `
        "Microsoft.VSTS.Scheduling.CompletedWork=$newCompleted" `
        --organization $AzureDevOpsConfig.Org -o json 2>&1 | ConvertFrom-Json
    $actualRem = $result.fields.'Microsoft.VSTS.Scheduling.RemainingWork'
    $actualComp = $result.fields.'Microsoft.VSTS.Scheduling.CompletedWork'
    Write-Host ("Task {0}: Remaining {1} h → {2} h  |  Spent {3} h → {4} h  (-{5} h)" -f $TaskId, $remaining, $actualRem, $completed, $actualComp, $HoursToDeduct) -ForegroundColor Cyan
}
