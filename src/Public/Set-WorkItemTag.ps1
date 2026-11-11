function Set-WorkItemTag {
    <#
    .SYNOPSIS
        Adds, removes or replaces the tags of an Azure DevOps work item.
    .DESCRIPTION
        Fetches a work item by ID, detects its type and updates System.Tags. Works for every
        work-item type. Use -Add and/or -Remove to change individual tags, or -Set to replace
        all tags (an empty array clears them). Tag comparison is case-insensitive.
    .PARAMETER Id
        The ID of the work item to update.
    .PARAMETER Add
        Tags to add.
    .PARAMETER Remove
        Tags to remove.
    .PARAMETER Set
        Replaces all existing tags with these tags. Cannot be combined with -Add or -Remove.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .EXAMPLE
        Set-WorkItemTag -Id 25555 -Add 'needs refinement' -Remove 'needs PO','On Hold','pre-refinement'
    .EXAMPLE
        Set-WorkItemTag -Id 25555 -Set 'needs refinement' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Change')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Id,

        [Parameter(ParameterSetName = 'Change')]
        [string[]]$Add = @(),

        [Parameter(ParameterSetName = 'Change')]
        [string[]]$Remove = @(),

        [Parameter(Mandatory, ParameterSetName = 'Set')]
        [AllowEmptyCollection()]
        [string[]]$Set,

        [string]$Org = $AzureDevOpsConfig.Org
    )

    if (-not $Org) {
        Write-Error "No Azure DevOps organisation URL was provided and no active config is loaded."
        return
    }

    if ($PSCmdlet.ParameterSetName -eq 'Change' -and -not $Add -and -not $Remove) {
        Write-Error "Specify -Add, -Remove or -Set."
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

    $previous = [string]$item.fields.'System.Tags'
    $currentTags = @($previous -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

    if ($PSCmdlet.ParameterSetName -eq 'Set') {
        $newTags = @($Set | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
    }
    else {
        $newTags = @($currentTags | Where-Object { $t = $_; -not ($Remove | Where-Object { $_.Trim() -ieq $t }) })
        foreach ($tag in $Add) {
            $tag = $tag.Trim()
            if ($tag -and -not ($newTags | Where-Object { $_ -ieq $tag })) { $newTags += $tag }
        }
    }

    $value = $newTags -join '; '
    if ($value -ceq ($currentTags -join '; ')) {
        Write-Host "$type $Id already has these tags." -ForegroundColor Yellow
        return
    }

    $action = "Change tags from '$previous' to '$value'"
    if (-not $PSCmdlet.ShouldProcess("$type $Id", $action)) {
        return
    }

    # `az boards work-item update` only sends JSON-patch 'add', which merges tags; the $batch endpoint allows 'replace'.
    $batch = @(@{
            method  = 'PATCH'
            uri     = "/_apis/wit/workitems/${Id}?api-version=7.1"
            headers = @{ 'Content-Type' = 'application/json-patch+json' }
            body    = @(@{ op = 'replace'; path = '/fields/System.Tags'; value = $value })
        })
    $batchFile = [System.IO.Path]::GetTempFileName()
    try {
        ConvertTo-Json -InputObject $batch -Depth 6 -Compress | Set-Content -LiteralPath $batchFile -Encoding utf8 -WhatIf:$false
        $response = Invoke-AzJson -Action "Updating tags of $type $Id" -Command {
            az devops invoke --area wit --resource batch `
                --http-method post --in-file $batchFile `
                --media-type 'application/json' `
                --api-version 7.1 --organization $Org -o json
        }
    }
    finally {
        Remove-Item -LiteralPath $batchFile -Force -ErrorAction SilentlyContinue -WhatIf:$false
    }

    $entry = @($response.value)[0]
    if ($entry.code -ne 200) {
        throw "Updating tags of $type $Id failed (HTTP $($entry.code)).`n$($entry.body)"
    }
    $result = $entry.body | ConvertFrom-Json

    $actual = [string]$result.fields.'System.Tags'
    $actualSorted = @($actual -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object) -join '; '
    $expectedSorted = @($newTags | Sort-Object) -join '; '
    if ($actualSorted -ine $expectedSorted) {
        throw "$type $Id was updated, but verification returned tags '$actual' instead of '$value'."
    }

    Write-Host ("{0} {1}: Tags '{2}' -> '{3}'" -f $type, $Id, $previous, $actual) -ForegroundColor Green
}
