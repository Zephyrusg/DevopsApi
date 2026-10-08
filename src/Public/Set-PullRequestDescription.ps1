function Set-PullRequestDescription {
    <#
    .SYNOPSIS
        Updates the Markdown description of an Azure DevOps pull request.
    .DESCRIPTION
        Replaces the pull request description and verifies the value by reading the PR back.
    .PARAMETER Id
        The pull request ID.
    .PARAMETER Description
        The new Markdown description.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .EXAMPLE
        Set-PullRequestDescription -Id 12 -Description "## Summary`n- Updated configuration"
    .EXAMPLE
        Set-PullRequestDescription -Id 12 -Description "Updated" -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Id,

        [Parameter(Mandatory, Position = 1)]
        [AllowEmptyString()]
        [string]$Description,

        [string]$Org = $AzureDevOpsConfig.Org
    )

    if (-not $Org) {
        Write-Error "No Azure DevOps organisation URL was provided and no active config is loaded."
        return
    }

    $current = Invoke-AzJson -Action "Getting pull request $Id" -Command {
        az repos pr show --id $Id --organization $Org -o json
    }

    if (-not $current) {
        Write-Error "Pull request $Id not found."
        return
    }

    if ([string]$current.description -ceq $Description) {
        Write-Host "Pull request $Id already has this description." -ForegroundColor Yellow
        return
    }

    if (-not $PSCmdlet.ShouldProcess("Pull request $Id", "Replace description")) {
        return
    }

    $updated = Invoke-AzJson -Action "Updating description of pull request $Id" -Command {
        az repos pr update --id $Id --description $Description --organization $Org -o json
    }

    if ([string]$updated.description -cne $Description) {
        throw "Pull request $Id was updated, but verification returned a different description."
    }

    Write-Host "Pull request $Id description updated." -ForegroundColor Green
}