function Set-WorkItemTitle {
    <#
    .SYNOPSIS
        Updates the title of an Azure DevOps work item.
    .DESCRIPTION
        Fetches a work item by ID, detects its type and updates System.Title.
        Works for every work-item type.
    .PARAMETER Id
        The ID of the work item to update.
    .PARAMETER Title
        The new title.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .EXAMPLE
        Set-WorkItemTitle -Id 30389 -Title "Prod Regio West Europe (AWE) DCs herinrichten"
    .EXAMPLE
        Set-WorkItemTitle -Id 30389 -Title "New title" -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Id,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

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

    $previous = [string]$item.fields.'System.Title'
    if ($previous -ceq $Title) {
        Write-Host "$type $Id already has this title." -ForegroundColor Yellow
        return
    }

    if (-not $PSCmdlet.ShouldProcess("$type $Id", "Change title from '$previous' to '$Title'")) {
        return
    }

    $result = Invoke-AzJson -Action "Updating title of $type $Id" -Command {
        az boards work-item update --id $Id `
            --title $Title `
            --organization $Org -o json
    }

    $actual = [string]$result.fields.'System.Title'
    if ($actual -cne $Title) {
        throw "$type $Id was updated, but verification returned title '$actual' instead of '$Title'."
    }

    Write-Host ("{0} {1}: Title '{2}' -> '{3}'" -f $type, $Id, $previous, $actual) -ForegroundColor Green
}
