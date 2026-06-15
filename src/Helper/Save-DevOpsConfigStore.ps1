function Save-DevOpsConfigStore {
    param([hashtable]$Store)
    $path = Get-DevOpsConfigStorePath
    $Store | ConvertTo-Json -Depth 3 | Set-Content $path -Encoding UTF8
}
