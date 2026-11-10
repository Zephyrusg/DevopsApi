function Add-WorkItem {
    <#
    .SYNOPSIS
        Creates an Azure DevOps User Story or Bug.
    .DESCRIPTION
        Creates a work item in the configured Azure DevOps project. Optional
        fields can be used to set its description, acceptance criteria, tags,
        assignee, area path and iteration path.
    .PARAMETER Type
        Work-item type to create: User Story or Bug.
    .PARAMETER Title
        Title of the new work item.
    .PARAMETER Description
        Description of the work item.
    .PARAMETER AcceptanceCriteria
        Acceptance criteria for a User Story.
    .PARAMETER Tags
        Tags to add to the work item.
    .PARAMETER AssignedTo
        User to assign the work item to.
    .PARAMETER AreaPath
        Area path for the work item.
    .PARAMETER IterationPath
        Iteration path for the work item.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .PARAMETER Project
        Azure DevOps project. Defaults to the active config.
    .EXAMPLE
        Add-WorkItem -Type 'User Story' -Title 'Add search' -Description 'Users can search items.'
    .EXAMPLE
        Add-WorkItem -Type Bug -Title 'Search fails' -Description 'Search returns no results.'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('User Story', 'Bug')]
        [string]$Type,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [string]$Description,
        [string]$AcceptanceCriteria,
        [string[]]$Tags,
        [string]$AssignedTo,
        [string]$AreaPath,
        [string]$IterationPath,
        [string]$Org = $AzureDevOpsConfig.Org,
        [string]$Project = $AzureDevOpsConfig.Project
    )

    if (-not $Org -or -not $Project) {
        Write-Error "Org and Project are required. Load an active config or pass them explicitly."
        return
    }

    if ($Type -eq 'Bug' -and $PSBoundParameters.ContainsKey('AcceptanceCriteria')) {
        Write-Error "AcceptanceCriteria is only supported when creating a User Story."
        return
    }

    $fields = @()
    if ($PSBoundParameters.ContainsKey('AcceptanceCriteria')) {
        $fields += "Microsoft.VSTS.Common.AcceptanceCriteria=$AcceptanceCriteria"
    }
    if ($PSBoundParameters.ContainsKey('Tags')) {
        $fields += "System.Tags=$($Tags -join '; ')"
    }
    if ($PSBoundParameters.ContainsKey('AssignedTo')) {
        $fields += "System.AssignedTo=$AssignedTo"
    }
    if ($PSBoundParameters.ContainsKey('AreaPath')) {
        $fields += "System.AreaPath=$AreaPath"
    }
    if ($PSBoundParameters.ContainsKey('IterationPath')) {
        $fields += "System.IterationPath=$IterationPath"
    }

    $target = "$Type '$Title'"
    if (-not $PSCmdlet.ShouldProcess($target, 'Create Azure DevOps work item')) {
        return
    }

    $arguments = @(
        'boards', 'work-item', 'create',
        '--type', $Type,
        '--title', $Title,
        '--organization', $Org,
        '--project', $Project
    )
    if ($PSBoundParameters.ContainsKey('Description')) {
        $arguments += @('--description', $Description)
    }
    if ($fields.Count -gt 0) {
        $arguments += @('--fields') + $fields
    }

    $result = Invoke-AzJson -Action "Creating $target" -Command {
        az @arguments -o json
    }

    return $result
}
