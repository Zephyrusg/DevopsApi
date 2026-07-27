function Set-WorkItemState {
    <#
    .SYNOPSIS
        Updates the state of an Azure DevOps work item.
    .DESCRIPTION
        Fetches a work item by ID and updates its System.State field. This
        supports Bugs, User Stories, Tasks and other Azure DevOps work-item
        types that have the requested state available in the active process.
    .PARAMETER Id
        The ID of the work item to update.
    .PARAMETER State
        The target state, for example New, Active, Resolved or Closed.
        Valid states depend on the work-item type and Azure DevOps process.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .EXAMPLE
        Set-WorkItemState -Id 29324 -State Active
    .EXAMPLE
        Set-WorkItemState -Id 29324 -State Closed -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Id,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$State,

        [string]$Org = $AzureDevOpsConfig.Org
    )

    if (-not $Org) {
        Write-Error "No Azure DevOps organisation URL was provided and no active config is loaded."
        return
    }

    $item = Invoke-AzJson -Action "Getting work item $Id" -Command {
        az boards work-item show --id $Id `
            --organization $Org -o json
    }

    if (-not $item) {
        Write-Error "Work item $Id not found."
        return
    }

    $type = $item.fields.'System.WorkItemType'
    if (-not $type) {
        Write-Error "Could not determine the type of work item $Id."
        return
    }

    $previousState = [string]$item.fields.'System.State'
    if ($previousState -eq $State) {
        Write-Host "$type $Id is already in state '$State'." -ForegroundColor Yellow
        return
    }

    $action = "Change state from '$previousState' to '$State'"
    if (-not $PSCmdlet.ShouldProcess("$type $Id", $action)) {
        return
    }

    $result = Invoke-AzJson -Action "Changing $type $Id state from '$previousState' to '$State'" -Command {
        az boards work-item update --id $Id `
            --fields "System.State=$State" `
            --organization $Org -o json
    }

    $actualState = [string]$result.fields.'System.State'
    if ($actualState -ne $State) {
        throw "$type $Id was updated, but verification returned state '$actualState' instead of '$State'."
    }

    Write-Host ("{0} {1}: State {2} -> {3}" -f $type, $Id, $previousState, $actualState) -ForegroundColor Green
}
