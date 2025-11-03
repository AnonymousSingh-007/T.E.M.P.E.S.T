function Export-ToJson {
    <#
    .SYNOPSIS
        Streams a PowerShell object to a JSON file efficiently, without using excessive memory.

    .DESCRIPTION
        Instead of building one huge in-memory JSON string, this version writes JSON progressively.
        Works well for large nested objects like T.E.M.P.E.S.T. results.

    .PARAMETER Data
        The PowerShell object to export (hashtable or dictionary of category arrays).

    .PARAMETER OutFile
        Path to the JSON file to write.

    .PARAMETER Depth
        Optional, ignored here (for compatibility with older calls).

    .OUTPUTS
        Path to the written JSON file.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] $Data,
        [Parameter(Mandatory = $true)] [string] $OutFile,
        [int] $Depth = 5
    )

    try {
        $dir = Split-Path -Path $OutFile -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir | Out-Null
        }

        # Start JSON stream
        $file = [System.IO.StreamWriter]::new($OutFile, $false, [System.Text.Encoding]::UTF8)
        $file.WriteLine('{')

        $keys = $Data.Keys
        $lastIndex = $keys.Count - 1
        $i = 0

        foreach ($key in $keys) {
            $file.Write("  `"$key`": ")

            # Each dataset converted individually to reduce memory
            $chunk = $Data[$key] | ConvertTo-Json -Depth 4 -Compress
            $file.Write($chunk)

            if ($i -lt $lastIndex) {
                $file.Write(',')
            }
            $file.WriteLine()
            $i++
        }

        $file.WriteLine('}')
        $file.Close()

        Write-Host "    [OK] JSON report saved: $OutFile" -ForegroundColor Green
        return (Get-Item -LiteralPath $OutFile).FullName
    }
    catch {
        Write-Warning "[!] Export-ToJson failed: $_"
        return $null
    }
}
