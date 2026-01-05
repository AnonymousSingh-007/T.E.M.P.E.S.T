function Invoke-Tempest {
    <#
    .SYNOPSIS
        Launches the full T.E.M.P.E.S.T. local attack surface enumeration.
        Includes ML-based port + service risk scoring via Python pipelines.
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
    # RUN PYTHON AI ANALYSIS (Ports + Services)
    # ----------------------------
    Write-Host "[AI] Running intelligent post-analysis (ML risk scoring)..." -ForegroundColor Cyan

    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    $analysisDir = Join-Path $projectRoot "analysis"
    $maliciousDir = Join-Path $projectRoot "malicious"
    $modelRoot = Join-Path $analysisDir "models"

    if (!(Test-Path $modelRoot)) { New-Item -ItemType Directory -Path $modelRoot | Out-Null }

    # ----------------------------
    # Ports Analysis
    # ----------------------------
    $portsCsv       = Join-Path $projectRoot "output\Ports.csv"
    $portsTrainCsv  = Join-Path $maliciousDir "fakePorts.csv"
    $portsPy        = Join-Path $analysisDir "ports_risk_pipeline.py"
    $portsModelDir  = Join-Path $modelRoot "ports"

    if ( (Test-Path $portsCsv) -and (Test-Path $portsPy) -and (Test-Path $portsTrainCsv) ) {
        if (!(Test-Path $portsModelDir)) { New-Item -ItemType Directory -Path $portsModelDir | Out-Null }
        Push-Location $analysisDir
        if (!(Test-Path (Join-Path $portsModelDir "ports_xgb.model"))) {
            Write-Host "[AI] Training Ports model..." -ForegroundColor Yellow
            python $portsPy train --data "$portsTrainCsv" --model_dir "$portsModelDir"
        }
        Write-Host "[AI] Scoring Ports..." -ForegroundColor Yellow
        python $portsPy score --data "$portsCsv" --model_dir "$portsModelDir"
        Pop-Location
        Write-Host "[AI] Ports ML analysis complete." -ForegroundColor Green
    }
    else {
        Write-Warning "[AI] Skipping Ports ML analysis (missing CSV or script)."
    }

    # ----------------------------
    # Services Analysis
    # ----------------------------
    $servicesCsv       = Join-Path $projectRoot "output\Services.csv"
    $servicesTrainCsv  = Join-Path $maliciousDir "fakeServices.csv"
    $servicesPy        = Join-Path $analysisDir "services_risk_pipeline.py"
    $servicesModelDir  = Join-Path $modelRoot "services"

    if ( (Test-Path $servicesCsv) -and (Test-Path $servicesPy) -and (Test-Path $servicesTrainCsv) ) {
        if (!(Test-Path $servicesModelDir)) { New-Item -ItemType Directory -Path $servicesModelDir | Out-Null }
        Push-Location $analysisDir
        if (!(Test-Path (Join-Path $servicesModelDir "services_xgb.model"))) {
            Write-Host "[AI] Training Services model..." -ForegroundColor Yellow
            python $servicesPy train --data "$servicesTrainCsv" --model_dir "$servicesModelDir"
        }
        Write-Host "[AI] Scoring Services..." -ForegroundColor Yellow
        python $servicesPy score --data "$servicesCsv" --model_dir "$servicesModelDir"
        Pop-Location
        Write-Host "[AI] Services ML analysis complete." -ForegroundColor Green
    }
    else {
        Write-Warning "[AI] Skipping Services ML analysis (missing CSV or script)."
    }

    # ----------------------------
    # Completion Output
    # ----------------------------
    Write-Host "`nReports saved to: $OutDir" -ForegroundColor Green
    Write-Host "    $(Split-Path $jsonOut -Leaf)"
    foreach ($csv in $csvOuts) { Write-Host "    $(Split-Path $csv -Leaf)" }
    Write-Host "    $(Split-Path $htmlOut -Leaf)"
    Write-Host "    Ports_with_risk.csv (if AI completed)"
    Write-Host "    Services_with_risk.csv (if AI completed)"

    return $results
}
