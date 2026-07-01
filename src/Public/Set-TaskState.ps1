function Set-TaskState {
    <#
    .SYNOPSIS
        Updates the state of an Azure DevOps Task.
    .DESCRIPTION
        Fetches the work item by ID, verifies that it is a Task, then updates
        the System.State field to the supplied state.
    .PARAMETER TaskId
        The work item ID of the Task to update.
    .PARAMETER State
        The target state to apply, for example "New", "Active", "Closed",
        "To Do", "In Progress", or "Done", depending on the Azure DevOps process.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .EXAMPLE
        Set-TaskState -TaskId 4821 -State Active
    .EXAMPLE
        Set-TaskState -TaskId 4821 -State "In Progress"
    #>
    param(
        [Parameter(Mandatory)][Alias('Id')][int]$TaskId,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$State,
        [string]$Org = $AzureDevOpsConfig.Org
    )

    if (-not $Org) {
        Write-Error "No Azure DevOps organisation URL was provided and no active config is loaded."
        return
    }

    $item = az boards work-item show --id $TaskId `
        --organization $Org -o json 2>&1 | ConvertFrom-Json

    if (-not $item) {
        Write-Error "Work item $TaskId not found."
        return
    }

    $type = $item.fields.'System.WorkItemType'
    if ($type -ne 'Task') {
        Write-Error "Work item $TaskId is '$type', not 'Task'."
        return
    }

    $previousState = $item.fields.'System.State'
    if ($previousState -eq $State) {
        Write-Host "Task $TaskId is already in state '$State'." -ForegroundColor Yellow
        return
    }

    $result = az boards work-item update --id $TaskId `
        --fields "System.State=$State" `
        --organization $Org -o json 2>&1 | ConvertFrom-Json

    $actualState = $result.fields.'System.State'
    Write-Host ("Task {0}: State {1} -> {2}" -f $TaskId, $previousState, $actualState) -ForegroundColor Cyan
}
