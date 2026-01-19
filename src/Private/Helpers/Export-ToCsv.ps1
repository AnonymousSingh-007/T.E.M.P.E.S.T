function Export-ToCsv {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)] [hashtable]$Report,
        [Parameter(Mandatory)] [string]$OutDir,
        [switch]$FlattenCombined
    )

    $csvFiles = @()

    try {
        if (-not (Test-Path $OutDir)) {
            New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
        }

        $combinedPath   = Join-Path $OutDir "tempest_combined.csv"
        $combinedExists = Test-Path $combinedPath

        foreach ($key in $Report.Keys) {
            $path  = Join-Path $OutDir ("{0}.csv" -f $key)
            $items = @($Report[$key])

            # Per-module CSV
            if ($items.Count -gt 0) {
                $items | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
                Write-Host ("    [OK] Exported {0}" -f (Split-Path $path -Leaf)) -ForegroundColor Green
            }
            else {
                "NoData" | Out-File -FilePath $path -Encoding UTF8
            }

            $csvFiles += $path

            # Combined CSV (append-safe, schema-tolerant)
            if ($FlattenCombined -and $items.Count -gt 0) {
                $out = foreach ($item in $items) {
                    $obj = $item.PSObject.Copy()
                    $obj | Add-Member -NotePropertyName "Category" -NotePropertyValue $key -Force
                    $obj
                }

                if (-not $combinedExists) {
                    $out | Export-Csv -Path $combinedPath -NoTypeInformation -Encoding UTF8
                    $combinedExists = $true
                }
                else {
                    $out | Export-Csv -Path $combinedPath -NoTypeInformation -Encoding UTF8 -Append -Force
                }

                Write-Host ("    [OK] Combined CSV: {0}" -f (Split-Path $combinedPath -Leaf)) -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Warning ("[!] Export-ToCsv failed: {0}" -f $_)
    }

    return $csvFiles
}
