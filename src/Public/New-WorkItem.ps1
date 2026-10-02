function New-WorkItem {
    <#
    .SYNOPSIS
        Creates a new Azure DevOps work item. Defaults to a User Story.
    .DESCRIPTION
        Creates a work item of the given type with an optional description, tags and parent link,
        and returns the created work item's ID, type, title and URL.
        Plain-text descriptions are HTML-encoded and line breaks become <br>; use -Html to pass HTML unchanged.
        For Bugs the description is written to Repro Steps.
    .PARAMETER Title
        The title of the work item.
    .PARAMETER Type
        The work-item type. Defaults to 'User Story'.
    .PARAMETER Description
        The description text.
    .PARAMETER Html
        Treat Description as HTML and do not encode it.
    .PARAMETER Tag
        Tags to put on the new work item.
    .PARAMETER ParentId
        ID of a work item to link as parent.
    .PARAMETER PredecessorId
        ID of a work item to link as predecessor (the new work item depends on it).
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .PARAMETER Project
        Azure DevOps project name. Defaults to the active config.
    .EXAMPLE
        New-WorkItem -Title "Implement - 2e Domain Controller"
    .EXAMPLE
        New-WorkItem -Title "Install NUC" -Type Task -ParentId 180 -Tag 'needs refinement' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [ValidateNotNullOrEmpty()]
        [string]$Type = 'User Story',

        [string]$Description,

        [switch]$Html,

        [string[]]$Tag = @(),

        [ValidateRange(1, [int]::MaxValue)]
        [int]$ParentId,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$PredecessorId,

        [string]$Org = $AzureDevOpsConfig.Org,
        [string]$Project = $AzureDevOpsConfig.Project
    )

    if (-not $Org -or -not $Project) {
        Write-Error "No Azure DevOps organisation/project was provided and no active config is loaded."
        return
    }

    if (-not $PSCmdlet.ShouldProcess("$Project", "Create $Type '$Title'")) {
        return
    }

    $fields = @()
    $tags = @($Tag | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
    if ($tags) { $fields += "System.Tags=$($tags -join '; ')" }

    if ($Description) {
        $value = if ($Html) { $Description } else { [System.Net.WebUtility]::HtmlEncode($Description) -replace "`r?`n", '<br>' }
        $descriptionField = if ($Type -eq 'Bug') { 'Microsoft.VSTS.TCM.ReproSteps' } else { 'System.Description' }
        $fields += "$descriptionField=$value"
    }

    $item = Invoke-AzJson -Action "Creating $Type '$Title'" -Command {
        $arguments = @('boards', 'work-item', 'create', '--type', $Type, '--title', $Title,
            '--organization', $Org, '--project', $Project, '-o', 'json')
        if ($fields) { $arguments += '--fields'; $arguments += $fields }
        az @arguments
    }

    if (-not $item -or -not $item.id) {
        throw "Creating $Type '$Title' returned no work item."
    }

    if ($ParentId) {
        $null = Invoke-AzJson -Action "Linking $Type $($item.id) to parent $ParentId" -Command {
            az boards work-item relation add --id $item.id --relation-type parent --target-id $ParentId `
                --organization $Org -o json
        }
    }

    if ($PredecessorId) {
        $null = Invoke-AzJson -Action "Linking $Type $($item.id) to predecessor $PredecessorId" -Command {
            az boards work-item relation add --id $item.id --relation-type predecessor --target-id $PredecessorId `
                --organization $Org -o json
        }
    }

    Write-Host ("{0} {1} created: {2}" -f $Type, $item.id, $Title) -ForegroundColor Green

    [PSCustomObject]@{
        Id    = $item.id
        Type  = $item.fields.'System.WorkItemType'
        Title = $item.fields.'System.Title'
        State = $item.fields.'System.State'
        Tags  = $item.fields.'System.Tags'
        Url   = "$($Org.TrimEnd('/'))/$([uri]::EscapeDataString($Project))/_workitems/edit/$($item.id)"
    }
}
