function Invoke-Tempest {
    <#
    .SYNOPSIS
        Launches the full T.E.M.P.E.S.T. local attack surface enumeration.
        Includes ML-based port risk scoring via ports_risk_pipeline.py
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

    $jsonPath = Join-Path $OutDir "tempest_index.json"
    $jsonOut  = Export-ToJson -Data $results -OutFile $jsonPath -Depth 8
    $csvOuts  = Export-ToCsv -Report $results -OutDir $OutDir -FlattenCombined
    $htmlOut  = Build-HtmlReport -Report $results -OutFile (Join-Path $OutDir "dashboard.html") -Title "T.E.M.P.E.S.T. Report"

    # ----------------------------
    # RUN PYTHON AI ANALYSIS (fixed paths)
    # ----------------------------
    Write-Host "[AI] Running intelligent post-analysis (port risk scoring)..." -ForegroundColor Cyan

    # Always resolve Ports.csv relative to the project root
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    $portsCsv = Join-Path $projectRoot "output\Ports.csv"

    if (Test-Path $portsCsv) {
        try {
            $candidates = @(
                (Join-Path $projectRoot "analysis\ports_risk_pipeline.py"),
                (Join-Path $projectRoot "analysis\analyze_tempest.py")
            )

            $scriptPath = $candidates | Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1

            if (-not $scriptPath) {
                Write-Warning "[AI] Could not find ports_risk_pipeline.py in analysis folder."
            }
            else {
                Write-Host "[AI] Using Python script: $scriptPath" -ForegroundColor Yellow
                $analysisDir = Split-Path $scriptPath -Parent

                Push-Location $analysisDir

                # Ensure models directory exists
                if (!(Test-Path ".\models")) {
                    New-Item -ItemType Directory -Path ".\models" | Out-Null
                }

                # Train if model missing
                if (!(Test-Path ".\models\ports_xgb.model")) {
                    Write-Host "[AI] No trained model found. Training model first..." -ForegroundColor Yellow
                    python $scriptPath train --data "$portsCsv"
                }

                Write-Host "[AI] Scoring ports with trained ML model..." -ForegroundColor Yellow
                python $scriptPath score --data "$portsCsv"

                Pop-Location

                Write-Host "[AI] Port risk analysis complete. See Ports_with_risk.csv in output directory." -ForegroundColor Green
            }
        }
        catch {
            if (Get-Location | Out-Null) { Pop-Location }
            Write-Warning "[AI] Failed to run Python ML analysis: $_"
        }
    }
    else {
        Write-Warning "[AI] Skipping ML analysis -- Ports.csv not found at $portsCsv"
    }

    # ----------------------------
    # Completion Output
    # ----------------------------
    Write-Host "`nReports saved to: $OutDir" -ForegroundColor Green
    Write-Host "    $(Split-Path $jsonOut -Leaf)"
    foreach ($csv in $csvOuts) { Write-Host "    $(Split-Path $csv -Leaf)" }
    Write-Host "    $(Split-Path $htmlOut -Leaf)"
    Write-Host "    Ports_with_risk.csv (if AI completed)"

    return $results
}
