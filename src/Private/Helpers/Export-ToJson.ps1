function Export-ToJson {
    <#
    .SYNOPSIS
        Exports a PowerShell object to JSON file (UTF-8).
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] $Data,
        [Parameter(Mandatory = $true)] [string]$OutFile,
        [int]$Depth = 8
    )

    try {
        $dir = Split-Path -Path $OutFile -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir | Out-Null
        }

        # Stream-write JSON to avoid memory overload
        $fileStream = [System.IO.StreamWriter]::new($OutFile, $false, [System.Text.UTF8Encoding]::new($false))
        try {
            $json = $Data | ConvertTo-Json -Depth $Depth -Compress
            $fileStream.Write($json)
        }
        finally {
            $fileStream.Close()
        }

        Write-Host "    [OK] JSON exported to $OutFile" -ForegroundColor Green
        return (Resolve-Path $OutFile)
    }
    catch {
        Write-Warning ("[!] Export-ToJson failed: {0}" -f $_)
        return $null
    }
}
