function Add-WorkItemToSprint {
    <#
    .SYNOPSIS
        Moves any Azure DevOps work item into the current team sprint.
    .DESCRIPTION
        Resolves the current sprint for the configured team, determines the
        work-item type automatically and updates its iteration path.
    .PARAMETER Id
        The ID of the work item to move.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .PARAMETER Project
        Azure DevOps project. Defaults to the active config.
    .PARAMETER Team
        Team whose current sprint should be used. Defaults to the active config.
    .EXAMPLE
        Add-WorkItemToSprint -Id 4821
    .EXAMPLE
        Add-WorkItemToSprint -Id 4821 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)][ValidateRange(1, [int]::MaxValue)][int]$Id,
        [string]$Org = $AzureDevOpsConfig.Org,
        [string]$Project = $AzureDevOpsConfig.Project,
        [string]$Team = $AzureDevOpsConfig.Team
    )

    if (-not $Org -or -not $Project -or -not $Team) {
        Write-Error "Org, Project and Team are required. Load an active config or pass them explicitly."
        return
    }

    $sprint = Invoke-AzJson -Action "Getting current sprint for team '$Team'" -Command {
        az boards iteration team list --team $Team --timeframe current `
            --organization $Org --project $Project -o json
    } | Select-Object -First 1

    if (-not $sprint -or -not $sprint.path) {
        Write-Error "Could not determine the current sprint for team '$Team'."
        return
    }

    $item = Invoke-AzJson -Action "Getting work item $Id" -Command {
        az boards work-item show --id $Id --organization $Org -o json
    }

    $type = $item.fields.'System.WorkItemType'
    $currentIteration = $item.fields.'System.IterationPath'
    $targetIteration = $sprint.path

    if (-not $type) {
        Write-Error "Could not determine the type of work item $Id."
        return
    }

    if ($currentIteration -eq $targetIteration) {
        Write-Host "$type $Id is already in sprint '$targetIteration'." -ForegroundColor Yellow
        return
    }

    $action = "Move from iteration '$currentIteration' to current sprint '$targetIteration'"
    if (-not $PSCmdlet.ShouldProcess("$type $Id", $action)) { return }

    $iterationField = "System.IterationPath=$targetIteration"
    $result = Invoke-AzJson -Action "Moving $type $Id to sprint '$targetIteration'" -Command {
        az boards work-item update --id $Id --fields $iterationField `
            --organization $Org -o json
    }

    $actualIteration = $result.fields.'System.IterationPath'
    Write-Host ("{0} {1}: Iteration {2} -> {3}" -f $type, $Id, $currentIteration, $actualIteration) -ForegroundColor Green
}
