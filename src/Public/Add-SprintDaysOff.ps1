function Add-SprintDaysOff {
    <#
    .SYNOPSIS
        Adds personal days off to your capacity entry for the current sprint.
    .DESCRIPTION
        Merges the supplied dates into your existing days-off list via the Azure DevOps REST API.
        Accepts dates in yyyy-MM-dd, dd-MM-yyyy or dd/MM/yyyy format.
        Duplicate dates are deduplicated automatically.
    .PARAMETER Dates
        One or more dates to mark as days off. Accepts yyyy-MM-dd, dd-MM-yyyy or dd/MM/yyyy.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .PARAMETER Project
        Azure DevOps project name. Defaults to the active config.
    .PARAMETER Team
        Team name. Defaults to the active config.
    .EXAMPLE
        Add-SprintDaysOff -Dates "2026-06-20", "2026-06-21"
    .EXAMPLE
        Add-SprintDaysOff -Dates "20-06-2026"
    #>
    param(
        [Parameter(Mandatory)][string[]]$Dates,
        [string]$Org = $AzureDevOpsConfig.Org,
        [string]$Project = $AzureDevOpsConfig.Project,
        [string]$Team = $AzureDevOpsConfig.Team
    )
    $ctx = Get-MyCapacityEntry -Org $Org -Project $Project -Team $Team
    if (-not $ctx) { return }

    # Parse input dates flexibly (yyyy-MM-dd or dd-MM-yyyy or dd/MM/yyyy)
    $formats = @('yyyy-MM-dd', 'dd-MM-yyyy', 'dd/MM/yyyy')
    $newDays = foreach ($d in $Dates) {
        $parsed = $null
        foreach ($fmt in $formats) {
            try { $parsed = [datetime]::ParseExact($d, $fmt, $null); break } catch {}
        }
        if (-not $parsed) { Write-Error "Could not parse date '$d'. Use yyyy-MM-dd or dd-MM-yyyy."; return }
        $iso = $parsed.ToString('yyyy-MM-dd')
        @{ start = "${iso}T00:00:00Z"; end = "${iso}T00:00:00Z" }
    }

    # Keep only valid existing entries (filter out broken 0001-01-01 leftovers)
    $existing = @($ctx.Me.daysOff) | Where-Object { $_ -and ([datetime]$_.start).Year -gt 1 }

    # Merge and deduplicate by start date
    $allDays = @(@($existing) + @($newDays) |
        Group-Object { $_.start } |
        ForEach-Object { $_.Group[0] })

    $patchUrl = "$($ctx.Org)/$($ctx.Project)/$($ctx.TeamEncoded)/_apis/work/teamsettings/iterations/$($ctx.Sprint.id)/capacities/$($ctx.Me.teamMember.id)?api-version=7.1"
    $body = @{ daysOff = $allDays } | ConvertTo-Json -Depth 4 -Compress
    Invoke-RestMethod -Uri $patchUrl -Headers @{ Authorization = "Basic $($ctx.Token)"; 'Content-Type' = 'application/json' } -Method PATCH -Body $body | Out-Null
    Write-Host "Days off set: $($allDays.Count) day(s) in $($ctx.Sprint.path)" -ForegroundColor Green
    $allDays | ForEach-Object { Write-Host "  $($_.start.Substring(0,10))" -ForegroundColor DarkGray }
}
