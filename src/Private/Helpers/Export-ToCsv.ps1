function Export-ToCsv {
    <#
    .SYNOPSIS
        Exports each report section to CSV, plus an optional combined flat file.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [hashtable]$Report,
        [Parameter(Mandatory = $true)] [string]$OutDir,
        [switch]$FlattenCombined
    )

    $csvFiles = @()
    try {
        if (-not (Test-Path $OutDir)) {
            New-Item -ItemType Directory -Path $OutDir | Out-Null
        }

        foreach ($key in $Report.Keys) {
            $path = Join-Path $OutDir ("{0}.csv" -f $key)
            if ($Report[$key] -and $Report[$key].Count -gt 0) {
                $Report[$key] | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
                Write-Host ("    [OK] Exported {0}" -f (Split-Path $path -Leaf)) -ForegroundColor Green
            }
            else {
                # Create empty CSV with header only
                "No data collected" | Out-File -FilePath $path -Encoding UTF8
                Write-Host ("    [WARN] {0} had no data" -f $key) -ForegroundColor Yellow
            }
            $csvFiles += $path
        }

        if ($FlattenCombined) {
            $flat = foreach ($key in $Report.Keys) {
                foreach ($item in $Report[$key]) {
                    if ($item) {
                        $obj = $item.PSObject.Copy()
                        $obj | Add-Member -NotePropertyName "Category" -NotePropertyValue $key -Force
                        $obj
                    }
                }
            }

            if ($flat) {
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
