function Export-ToCsv {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Report,

        [Parameter(Mandatory)]
        [string]$OutDir,

        [switch]$FlattenCombined
    )

    $csvFiles = @()

    try {
        if (-not (Test-Path $OutDir)) {
            New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
        }

        foreach ($key in $Report.Keys) {
            $items = @($Report[$key])
            $path  = Join-Path $OutDir "$key.csv"

            if ($items.Count -gt 0) {
                $items | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8 -Force
            }
            else {
                "NoData" | Out-File -FilePath $path -Encoding UTF8
            }

            Write-Host "    [OK] Exported $($key).csv" -ForegroundColor Green
            $csvFiles += $path
        }

        # ---- SAFE COMBINED CSV ----
        if ($FlattenCombined) {
            $flat = New-Object System.Collections.Generic.List[object]

            foreach ($key in $Report.Keys) {
                foreach ($item in @($Report[$key])) {
                    if ($item) {
                        $copy = $item.PSObject.Copy()
                        $copy | Add-Member Category $key -Force
                        $flat.Add($copy)
                    }
                }
            }

            if ($flat.Count -gt 0) {
                $combined = Join-Path $OutDir "tempest_combined.csv"
                $flat | Export-Csv -Path $combined -NoTypeInformation -Encoding UTF8 -Force
                Write-Host "    [OK] Combined CSV: tempest_combined.csv" -ForegroundColor Green
                $csvFiles += $combined
            }
        }
    }
    catch {
        Write-Warning "[!] Export-ToCsv failed: $_"
    }

    return $csvFiles
}
