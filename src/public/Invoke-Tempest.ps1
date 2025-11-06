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

    # ----------------------------
    # Load Helpers and Private Modules
    # ----------------------------
    $helpersPath = Join-Path $PSScriptRoot "..\Private\Helpers"
    if (Test-Path $helpersPath) {
        Get-ChildItem -Path $helpersPath -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    }

    $privatePath = Join-Path $PSScriptRoot "..\Private"
    if (Test-Path $privatePath) {
        Get-ChildItem -Path $privatePath -Filter "Get-*.ps1" | ForEach-Object { . $_.FullName }
    }

    Write-Verbose "[+] Loaded Private modules from: $privatePath"
    Write-Verbose "[+] Loaded Helper modules from: $helpersPath"

    # ----------------------------
    # Define Modules to Run
    # ----------------------------
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

    # ----------------------------
    # Run Enumerations
    # ----------------------------
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

    # JSON Export (index only to save memory)
    $jsonPath = Join-Path $OutDir "tempest_index.json"
    $jsonOut  = Export-ToJson -Data $results -OutFile $jsonPath -Depth 8

    # CSV Export (flattened and combined)
    $csvOuts = Export-ToCsv -Report $results -OutDir $OutDir -FlattenCombined

    # HTML Dashboard (primary UI report)
    $htmlOut = Build-HtmlReport -Report $results -OutFile (Join-Path $OutDir "dashboard.html") -Title "T.E.M.P.E.S.T. Report"

    # ----------------------------
    # RUN PYTHON AI ANALYSIS
    # ----------------------------
    Write-Host "[AI] Running intelligent post-analysis..." -ForegroundColor Cyan
    $csvFile = Join-Path $OutDir "tempest_combined.csv"

    if (Test-Path $csvFile) {
        try {
            python ./analysis/analyze_tempest.py $csvFile
            Write-Host "[AI] Analysis complete. See risk_dashboard.html" -ForegroundColor Green
        }
        catch {
            Write-Warning "[AI] Failed to run Python analysis: $_"
        }
    }
    else {
        Write-Warning "[AI] Skipping analysis -- no combined CSV found."
    }

    # ----------------------------
    # Completion Output
    # ----------------------------
    Write-Host "`nReports saved to: $OutDir" -ForegroundColor Green
    Write-Host "    $(Split-Path $jsonOut -Leaf)"
    foreach ($csv in $csvOuts) { Write-Host "    $(Split-Path $csv -Leaf)" }
    Write-Host "    $(Split-Path $htmlOut -Leaf)"
    Write-Host "    risk_dashboard.html (if AI completed)"

    return $results
}
