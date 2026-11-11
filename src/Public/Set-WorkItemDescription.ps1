function Set-WorkItemDescription {
    <#
    .SYNOPSIS
        Updates the description of an Azure DevOps work item.
    .DESCRIPTION
        Fetches a work item by ID, detects its type and updates the System.Description field
        (for Bugs, the Repro Steps field Microsoft.VSTS.TCM.ReproSteps is used instead).
        Plain text is HTML-encoded and line breaks are converted to <br>. Use -Html to
        pass ready-made HTML unchanged.
    .PARAMETER Id
        The ID of the work item to update.
    .PARAMETER Description
        The new description text.
    .PARAMETER Html
        Treat Description as HTML and do not encode it.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .EXAMPLE
        Set-WorkItemDescription -Id 25555 -Description "Als IAM engineer`nWil ik ..."
    .EXAMPLE
        Set-WorkItemDescription -Id 25555 -Description "<b>Als</b> ..." -Html -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Id,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [switch]$Html,

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

    $fieldName = if ($type -eq 'Bug') { 'Microsoft.VSTS.TCM.ReproSteps' } else { 'System.Description' }

    $value = if ($Html) {
        $Description
    }
    else {
        ([System.Net.WebUtility]::HtmlEncode($Description) -replace "`r?`n", '<br>')
    }

    $current = [string]$item.fields.$fieldName
    if ($current -eq $value) {
        Write-Host "$type $Id already has this description." -ForegroundColor Yellow
        return
    }

    if (-not $PSCmdlet.ShouldProcess("$type $Id", "Replace $fieldName")) {
        return
    }

    $result = Invoke-AzJson -Action "Updating description of $type $Id" -Command {
        az boards work-item update --id $Id `
            --fields "$fieldName=$value" `
            --organization $Org -o json
    }

    if ([string]::IsNullOrWhiteSpace([string]$result.fields.$fieldName)) {
        throw "$type $Id was updated, but verification returned an empty $fieldName."
    }

    Write-Host "$type ${Id}: $fieldName updated" -ForegroundColor Green
}
