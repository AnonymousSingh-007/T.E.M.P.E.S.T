function Export-ToJson {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable] $Data,

        [Parameter(Mandatory)]
        [string] $OutFile,

        [int] $Depth = 10
    )

    try {
        $dir = Split-Path -Path $OutFile -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $stream    = [System.IO.StreamWriter]::new($OutFile, $false, $utf8NoBom)

        $stream.WriteLine("{")

        $keys = $Data.Keys
        $i = 0

        foreach ($key in $keys) {
            $i++

            # Write property name
            $stream.Write("  `"$key`": ")

            # Serialize ONLY this section
            $jsonPart = $Data[$key] | ConvertTo-Json -Depth $Depth -Compress

            $stream.Write($jsonPart)

            if ($i -lt $keys.Count) {
                $stream.WriteLine(",")
            }
            else {
                $stream.WriteLine()
            }

            # FORCE flush to disk
            $stream.Flush()
        }

        $stream.WriteLine("}")
        $stream.Flush()
        $stream.Close()

        Write-Host "    [OK] JSON report saved (streamed): $OutFile" -ForegroundColor Green
        return (Resolve-Path $OutFile).Path
    }
    catch {
        Write-Warning "[!] Export-ToJson failed: $($_.Exception.Message)"
        return $null
    }
}
