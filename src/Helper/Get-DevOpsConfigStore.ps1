function Get-DevOpsConfigStore {
    $path = Get-DevOpsConfigStorePath
    if (-not (Test-Path $path)) { return @{} }
    $json = Get-Content $path -Raw | ConvertFrom-Json
    $store = @{}
    foreach ($prop in $json.PSObject.Properties) {
        $store[$prop.Name] = @{
            Org     = $prop.Value.Org
            Project = $prop.Value.Project
            Team    = $prop.Value.Team
            Me      = $prop.Value.Me
            PAT     = $prop.Value.PAT
        }
    }
    return $store
}
