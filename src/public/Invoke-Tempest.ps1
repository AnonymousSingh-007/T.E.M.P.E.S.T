function Invoke-Tempest {
    <#
    .SYNOPSIS
        Launches the full T.E.M.P.E.S.T. local attack surface enumeration.
    #>

    [CmdletBinding()]
    param (
        [string]$OutDir = ".\output",
        [string[]]$Include
    )

    Write-Host "`n[INFO]  Initializing T.E.M.P.E.S.T. enumeration..." -ForegroundColor Cyan

    # Ensure output directory exists
    if (!(Test-Path $OutDir)) {
        New-Item -ItemType Directory -Path $OutDir | Out-Null
    }

    # Import all Private Get-* functions dynamically
    $privatePath = Join-Path $PSScriptRoot "..\Private"
    Get-ChildItem -Path $privatePath -Filter "Get-*.ps1" | ForEach-Object {
        . $_.FullName
    }

    Write-Verbose "[+] Loaded Private modules from: $privatePath"

    # Module mapping
    $modules = @{
        "HostSummary"       = "Get-HostSummary"
        "Services"          = "Get-LocalServices"
        "Ports"             = "Get-ListeningPorts"
        "Autostart"         = "Get-Autostart"
        "FirewallRules"     = "Get-FirewallRules"
        "ScheduledTasks"    = "Get-ScheduledTasks"
        "Drivers"           = "Get-Drivers"
        "BrowserExtensions" = "Get-BrowserExtensions"
    }

    if ($Include) {
        $modules = $modules.GetEnumerator() |
            Where-Object { $Include -contains $_.Key } |
            ForEach-Object { $_ }
    }

    $results = @{}
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    foreach ($mod in $modules.Keys) {
        Write-Host "[*] Running $mod enumeration..." -ForegroundColor Yellow
        try {
            $fn = Get-Command $modules[$mod] -ErrorAction Stop
            $data = & $fn
            $results[$mod] = $data
            Write-Host ("    -> Collected {0} items." -f ($data.Count)) -ForegroundColor Green
        }
        catch {
            Write-Warning ("[-] Failed running {0}: {1}" -f $mod, $_)
            $results[$mod] = @()
        }
    }

    $timer.Stop()
    Write-Host ("`n[SUCCESS] Enumeration completed in {0}s" -f [math]::Round($timer.Elapsed.TotalSeconds,2)) -ForegroundColor Cyan

    # Export section
    Write-Host "[+] Exporting results..." -ForegroundColor Magenta

    $jsonPath = Join-Path $OutDir "tempest.json"
    $csvPath  = Join-Path $OutDir "tempest.csv"
    $htmlPath = Join-Path $OutDir "tempest.html"

    $results | ConvertTo-Json -Depth 5 | Out-File -Encoding UTF8 $jsonPath

    $flat = foreach ($key in $results.Keys) {
        foreach ($item in $results[$key]) {
            $item | Add-Member -NotePropertyName "Category" -NotePropertyValue $key -Force
            $item
        }
    }
    $flat | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

    # HTML report
    $html = @"
<html>
<head>
<title>T.E.M.P.E.S.T. Report</title>
<style>
body { font-family: Consolas, monospace; background-color: #0f111a; color: #ddd; padding: 20px; }
h1 { color: #7ed957; }
h2 { color: #58a6ff; }
table { border-collapse: collapse; width: 100%; margin-bottom: 40px; }
th, td { border: 1px solid #333; padding: 6px 10px; font-size: 13px; }
th { background-color: #1e222e; color: #fff; }
</style>
</head>
<body>
<h1>🛰️ T.E.M.P.E.S.T. Report</h1>
<p>Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
"@

    foreach ($key in $results.Keys) {
        $html += "<h2>$key</h2><table><tr>"
        if ($results[$key].Count -gt 0) {
            $columns = $results[$key][0].PSObject.Properties.Name
            foreach ($col in $columns) { $html += "<th>$col</th>" }
            $html += "</tr>"
            foreach ($item in $results[$key]) {
                $html += "<tr>"
                foreach ($col in $columns) { 
                    $html += "<td>$($item.$col)</td>" 
                }
                $html += "</tr>"
            }
        }
        else {
            $html += "<tr><td><i>No data collected</i></td></tr>"
        }
        $html += "</table>"
    }

    $html += "</body></html>"
    $html | Out-File -Encoding UTF8 $htmlPath

    Write-Host "`n Reports saved to: $OutDir" -ForegroundColor Green
    Write-Host "    tempest.json"
    Write-Host "    tempest.csv"
    Write-Host "    tempest.html"

return $results
}


