# Dot-source Helper scripts first (internal, not exported)
$helperPath = Join-Path $PSScriptRoot 'Helper'
if (Test-Path $helperPath) {
    Get-ChildItem -Path $helperPath -Filter '*.ps1' | ForEach-Object { . $_.FullName }
}

# Auto-load config store from JSON into session
$global:AzureDevOpsConfigs = Get-DevOpsConfigStore

# Dot-source Private functions (internal, not exported)
$privatePath = Join-Path $PSScriptRoot 'Private'
if (Test-Path $privatePath) {
    Get-ChildItem -Path $privatePath -Filter '*.ps1' | ForEach-Object { . $_.FullName }
}

# Dot-source Public functions (exported)
$publicPath = Join-Path $PSScriptRoot 'Public'
if (Test-Path $publicPath) {
    Get-ChildItem -Path $publicPath -Filter '*.ps1' | ForEach-Object { . $_.FullName }
}

# Export all Public functions
$publicFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue |
Select-Object -ExpandProperty BaseName

Export-ModuleMember -Function $publicFunctions
