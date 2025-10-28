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

    Write-Host "`n[INFO] Initializing T.E.M.P.E.S.T. enumeration..." -ForegroundColor Cyan

    # Ensure output directory exists
    if (!(Test-Path $OutDir)) {
        New-Item -ItemType Directory -Path $OutDir | Out-Null
    }

    # Import helpers
    $helpersPath = Join-Path $PSScriptRoot "..\Private\Helpers"
    Get-ChildItem -Path $helpersPath -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Import Private Get-* functions dynamically
    $privatePath = Join-Path $PSScriptRoot "..\Private"
    Get-ChildItem -Path $privatePath -Filter "Get-*.ps1" | ForEach-Object { . $_.FullName }

    Write-Verbose "[+] Loaded Private modules from: $privatePath"
    Write-Verbose "[+] Loaded Helper modules from: $helpersPath"

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
            $count = if ($data -is [System.Collections.IEnumerable]) { $data.Count } else { 1 }
            Write-Host ("    -> Collected {0} items." -f $count) -ForegroundColor Green
        }
        catch {
            Write-Warning ("[-] Failed running {0}: {1}" -f $mod, $_)
            $results[$mod] = @()
        }
    }

    $timer.Stop()
    Write-Host ("`n[SUCCESS] Enumeration completed in {0}s" -f [math]::Round($timer.Elapsed.TotalSeconds,2)) -ForegroundColor Cyan

    # ----------------------------
    # EXPORT RESULTS VIA HELPERS
    # ----------------------------
    Write-Host "[+] Exporting results..." -ForegroundColor Magenta

    # Export all JSON files separately to save memory
    $jsonPath = Join-Path $OutDir "tempest_index.json"
    $jsonOut  = Export-ToJson -Data $results -OutFile $jsonPath -Depth 8


    # Export CSV (flattened combined)
    $csvOuts = Export-ToCsv -Report $results -OutDir $OutDir -FlattenCombined

    # Build HTML dashboard
    $htmlOut = Build-HtmlReport -Report $results -OutFile (Join-Path $OutDir "dashboard.html") -Title "T.E.M.P.E.S.T. Report"

    Write-Host "`nReports saved to: $OutDir" -ForegroundColor Green
    Write-Host "    tempest_index.json"
    foreach ($csv in $csvOuts) { Write-Host "    $(Split-Path $csv -Leaf)" }
    Write-Host "    $(Split-Path $htmlOut -Leaf)"

    return $results
}
