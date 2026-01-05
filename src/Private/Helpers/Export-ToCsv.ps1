function Export-ToCsv {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [hashtable]$Report,
        [Parameter(Mandatory = $true)] [string]$OutDir,
        [switch]$FlattenCombined
    )

    $csvFiles = @()
    try {
        if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

        foreach ($key in $Report.Keys) {
            $path = Join-Path $OutDir ("{0}.csv" -f $key)
            $items = @($Report[$key])

            if ($items.Count -gt 0) {
                $items | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
                Write-Host ("    [OK] Exported {0}" -f (Split-Path $path -Leaf)) -ForegroundColor Green
            }
            else {
                # Create empty CSV with AI-compatible headers
                $headers = switch ($key) {
                    "Ports"    { "LocalPort,Protocol,LocalAddress,ProcessName,RiskScore" }
                    "Services" { "ServiceName,Path,StartMode,User,Description,RiskScore" }
                    default    { "NoData" }
                }
                $headers | Out-File -FilePath $path -Encoding UTF8
                Write-Host ("    [WARN] {0} had no data, wrote placeholder CSV" -f $key) -ForegroundColor Yellow
            }

            $csvFiles += $path
        }

        # Flatten combined CSV if requested
        if ($FlattenCombined) {
            $flat = foreach ($key in $Report.Keys) {
                foreach ($item in @($Report[$key])) {
                    if ($item) {
                        $obj = $item.PSObject.Copy()
                        $obj | Add-Member -NotePropertyName "Category" -NotePropertyValue $key -Force
                        $obj
                    }
                }
            }

            if ($flat.Count -gt 0) {
                $combinedPath = Join-Path $OutDir "tempest_combined.csv"
                $flat | Export-Csv -Path $combinedPath -NoTypeInformation -Encoding UTF8
                $csvFiles += $combinedPath
                Write-Host ("    [OK] Combined CSV: {0}" -f (Split-Path $combinedPath -Leaf)) -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Warning ("[!] Export-ToCsv failed: {0}" -f $_)
    }

    return $csvFiles
}
