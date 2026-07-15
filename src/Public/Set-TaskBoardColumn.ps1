function Set-TaskBoardColumn {
    <#
    .SYNOPSIS
        Moves a Task to a column on the current sprint Taskboard.
    .DESCRIPTION
        Resolves the current iteration and the configured Taskboard columns for
        the team, then moves the Task using the Azure DevOps Taskboard API.
        This distinguishes columns that map to the same work-item state, such as
        Waiting and Review.
    .PARAMETER TaskId
        The ID of the Task to move.
    .PARAMETER Column
        The Taskboard column name, for example Active, Waiting, Review or Closed.
    .EXAMPLE
        Set-TaskBoardColumn -TaskId 29461 -Column Review
    .EXAMPLE
        Set-TaskBoardColumn -TaskId 29461 -Column Review -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)][Alias('Id')][ValidateRange(1, [int]::MaxValue)][int]$TaskId,
        [Parameter(Mandatory, Position = 1)][ValidateNotNullOrEmpty()][string]$Column,
        [string]$Org = $AzureDevOpsConfig.Org,
        [string]$Project = $AzureDevOpsConfig.Project,
        [string]$Team = $AzureDevOpsConfig.Team
    )

    if (-not $Org -or -not $Project -or -not $Team) {
        Write-Error "Org, Project and Team are required. Load an active config or pass them explicitly."
        return
    }

    $item = Invoke-AzJson -Action "Getting work item $TaskId" -Command {
        az boards work-item show --id $TaskId --organization $Org -o json
    }

    $type = $item.fields.'System.WorkItemType'
    if ($type -ne 'Task') {
        Write-Error "Work item $TaskId is '$type', not 'Task'."
        return
    }

    $sprint = Invoke-AzJson -Action "Getting current sprint for team '$Team'" -Command {
        az boards iteration team list --team $Team --timeframe current `
            --organization $Org --project $Project -o json
    } | Select-Object -First 1

    if (-not $sprint -or -not $sprint.id) {
        Write-Error "Could not determine the current sprint for team '$Team'."
        return
    }

    $iterationPath = [string]$sprint.path
    $iterationId = [string]$sprint.id
    if ($item.fields.'System.IterationPath' -ne $iterationPath) {
        Write-Error "Task $TaskId is not in the current sprint '$iterationPath'. Use Add-WorkItemToSprint first."
        return
    }

    $columnConfig = Invoke-AzJson -Action "Getting Taskboard columns for team '$Team'" -Command {
        az devops invoke --area work --resource taskboardcolumns `
            --route-parameters project=$Project team=$Team `
            --organization $Org --api-version 7.1 -o json
    }

    $targetColumn = @($columnConfig.columns) |
        Where-Object { $_.name -eq $Column } |
        Select-Object -First 1

    if (-not $targetColumn) {
        $available = @($columnConfig.columns | ForEach-Object { $_.name }) -join ', '
        Write-Error "Column '$Column' does not exist on the '$Team' Taskboard. Available columns: $available."
        return
    }

    $boardItems = Invoke-AzJson -Action "Getting current Taskboard items" -Command {
        az devops invoke --area work --resource taskboardworkitems `
            --route-parameters project=$Project team=$Team iterationId=$iterationId `
            --organization $Org --api-version 7.1 -o json
    }
    $boardItem = @($boardItems.value) | Where-Object { $_.workItemId -eq $TaskId } | Select-Object -First 1

    if (-not $boardItem) {
        Write-Error "Task $TaskId was not found on the current sprint Taskboard."
        return
    }

    $currentColumn = [string]$boardItem.column
    $targetName = [string]$targetColumn.name
    if ($currentColumn -eq $targetName) {
        Write-Host "Task $TaskId is already in column '$targetName'." -ForegroundColor Yellow
        return
    }

    if (-not $PSCmdlet.ShouldProcess("Task $TaskId", "Move from Taskboard column '$currentColumn' to '$targetName'")) {
        return
    }

    $requestFile = [System.IO.Path]::GetTempFileName()
    try {
        @{ newColumn = $targetName } | ConvertTo-Json -Compress |
            Set-Content -LiteralPath $requestFile -Encoding utf8 -WhatIf:$false

        Invoke-AzJson -Action "Moving Task $TaskId to Taskboard column '$targetName'" -AllowEmpty -Command {
            az devops invoke --area work --resource taskboardworkitems `
                --route-parameters project=$Project team=$Team iterationId=$iterationId workItemId=$TaskId `
                --http-method PATCH --in-file $requestFile `
                --organization $Org --api-version 7.1 -o json
        } | Out-Null
    }
    finally {
        Remove-Item -LiteralPath $requestFile -Force -ErrorAction SilentlyContinue -WhatIf:$false
    }

    $updatedItems = Invoke-AzJson -Action "Verifying Taskboard column for Task $TaskId" -Command {
        az devops invoke --area work --resource taskboardworkitems `
            --route-parameters project=$Project team=$Team iterationId=$iterationId `
            --organization $Org --api-version 7.1 -o json
    }
    $updatedItem = @($updatedItems.value) | Where-Object { $_.workItemId -eq $TaskId } | Select-Object -First 1
    $actualColumn = [string]$updatedItem.column

    if ($actualColumn -ne $targetName) {
        throw "Task $TaskId was updated, but Taskboard verification returned column '$actualColumn' instead of '$targetName'."
    }

    Write-Host ("Task {0}: Column {1} -> {2}" -f $TaskId, $currentColumn, $actualColumn) -ForegroundColor Green
}
