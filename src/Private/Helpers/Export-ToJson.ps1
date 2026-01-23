function Export-ToJson {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Data,

        [Parameter(Mandatory)]
        [string]$OutFile,

        [int]$Depth = 6
    )

    try {
        $dir = Split-Path $OutFile -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        # ---- SANITIZE OBJECTS (PS 5.1 CRITICAL) ----
        $safe = @{}

        foreach ($key in $Data.Keys) {
            $safe[$key] = foreach ($item in @($Data[$key])) {
                if (-not $item) { continue }

                $o = [ordered]@{}
                foreach ($p in $item.PSObject.Properties) {
                    if ($p.MemberType -in 'NoteProperty','Property') {
                        try {
                            $o[$p.Name] = $p.Value
                        }
                        catch {
                            $o[$p.Name] = '[UNREADABLE]'
                        }
                    }
                }
                [pscustomobject]$o
            }
        }

        $safe | ConvertTo-Json -Depth $Depth |
            Out-File -Encoding UTF8 -Force $OutFile

        Write-Host "    [OK] JSON report saved: $OutFile" -ForegroundColor Green
        return (Resolve-Path $OutFile).Path
    }
    catch {
        Write-Warning "[!] Export-ToJson failed: $($_.Exception.Message)"
        return $null
    }
}
