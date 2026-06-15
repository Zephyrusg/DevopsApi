function Get-DevOpsConfig {
    <#
    .SYNOPSIS
        Lists all stored Azure DevOps configs, or shows details of a specific one.
    .DESCRIPTION
        Without parameters, prints all config names with their org/project. The currently
        active config (set via Set-DevOpsConfig) is marked with an asterisk.
        With -Name, shows the full details of that config including a masked PAT.
    .PARAMETER Name
        Name of a specific config to inspect. Omit to list all.
    .EXAMPLE
        Get-DevOpsConfig
    .EXAMPLE
        Get-DevOpsConfig -Name "MYORG-MYPROJECT"
    #>
    param([string]$Name)

    # Single config lookup
    if ($Name) {
        if (-not $AzureDevOpsConfigs.ContainsKey($Name)) {
            Write-Error "Config '$Name' not found. Available: $($AzureDevOpsConfigs.Keys -join ', ')"
            return
        }
        $cfg = $AzureDevOpsConfigs[$Name]
        Write-Host "`n[$Name]" -ForegroundColor Cyan
        Write-Host "  Org:     $($cfg.Org)"
        Write-Host "  Project: $($cfg.Project)"
        Write-Host "  Team:    $($cfg.Team)"
        Write-Host "  Me:      $($cfg.Me)"
        Write-Host "  PAT:     $('*' * [Math]::Min(8, $cfg.PAT.Length))..."
        Write-Host ""
        return
    }

    # List all configs
    if (-not $AzureDevOpsConfigs -or $AzureDevOpsConfigs.Count -eq 0) {
        Write-Host "No configs found. Use Add-DevOpsConfig to add one." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    foreach ($key in ($AzureDevOpsConfigs.Keys | Sort-Object)) {
        $cfg = $AzureDevOpsConfigs[$key]
        $isActive = $key -eq $global:AzureDevOpsActiveConfig
        $marker = if ($isActive) { " *" } else { "  " }
        $color = if ($isActive) { "Green" } else { "White" }
        Write-Host "$marker[$key]  $($cfg.Org) / $($cfg.Project)" -ForegroundColor $color
    }
    if ($global:AzureDevOpsActiveConfig) {
        Write-Host "`n  * active config" -ForegroundColor DarkGray
    }
    Write-Host ""
}
