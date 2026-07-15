function Set-MyWorkItem {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)][ValidateRange(1, [int]::MaxValue)][int]$Id,
        [switch]$Unassign,
        [string]$Org = $AzureDevOpsConfig.Org,
        [string]$Me = $AzureDevOpsConfig.Me
    )

    if (-not $Org) {
        Write-Error "No Azure DevOps organisation URL was provided and no active config is loaded."
        return
    }
    if (-not $Unassign -and -not $Me) {
        Write-Error "Your Azure DevOps account is unknown. Set 'Me' in the active config or pass -Me."
        return
    }

    $item = Invoke-AzJson -Action "Getting work item $Id" -Command {
        az boards work-item show --id $Id --organization $Org -o json
    }
    $type = $item.fields.'System.WorkItemType'
    if (-not $type) {
        Write-Error "Could not determine the type of work item $Id."
        return
    }

    $currentAssignee = $item.fields.'System.AssignedTo'
    $currentName = if ($currentAssignee.displayName) { $currentAssignee.displayName } elseif ($currentAssignee) { [string]$currentAssignee } else { $null }
    $currentAccount = if ($currentAssignee.uniqueName) { $currentAssignee.uniqueName } elseif ($currentAssignee.mailAddress) { $currentAssignee.mailAddress } else { $currentName }

    if ($Unassign -and -not $currentAssignee) {
        Write-Host "$type $Id is already unassigned." -ForegroundColor Yellow
        return
    }
    if (-not $Unassign -and $currentAccount -and $currentAccount.Equals($Me, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "$type $Id is already assigned to you ($currentName)." -ForegroundColor Yellow
        return
    }

    $oldName = if ($currentName) { $currentName } else { 'Unassigned' }
    $target = if ($Unassign) { 'Unassigned' } else { $Me }
    $action = "Change Assigned To from '$oldName' to '$target'"
    if (-not $PSCmdlet.ShouldProcess("$type $Id", $action)) { return }

    $assignedToField = if ($Unassign) { 'System.AssignedTo=' } else { "System.AssignedTo=$Me" }
    $result = Invoke-AzJson -Action "Updating assignment for $type $Id" -Command {
        az boards work-item update --id $Id --fields $assignedToField --organization $Org -o json
    }

    $newAssignee = $result.fields.'System.AssignedTo'
    $newName = if ($newAssignee.displayName) { $newAssignee.displayName } elseif ($newAssignee) { [string]$newAssignee } else { 'Unassigned' }
    Write-Host ("{0} {1}: Assigned To {2} -> {3}" -f $type, $Id, $oldName, $newName) -ForegroundColor Green
}
