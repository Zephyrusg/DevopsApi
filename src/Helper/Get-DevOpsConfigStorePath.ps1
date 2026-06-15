function Get-DevOpsConfigStorePath {
    return Join-Path $env:USERPROFILE '.devops-configs.json'
}
