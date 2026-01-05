function Export-ToJson {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Data,

        [Parameter(Mandatory)]
        [string]$OutFile,

        [int]$Depth = 8
    )

    try {
        $dir = Split-Path -Path $OutFile -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir | Out-Null
        }

        # SAFE JSON SERIALIZATION (no manual buffering)
        $json = $Data | ConvertTo-Json -Depth $Depth -Compress

        # Write atomically
        [System.IO.File]::WriteAllText(
            $OutFile,
            $json,
            [System.Text.Encoding]::UTF8
        )

        Write-Host "    [OK] JSON report saved: $OutFile" -ForegroundColor Green
        return (Resolve-Path $OutFile).Path
    }
    catch {
        Write-Warning "[!] Export-ToJson failed: $_"
        return $null
    }
}
