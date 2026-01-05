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

    # Ensure UTF-8 output
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    Write-Host "`n[INFO] Initializing T.E.M.P.E.S.T. enumeration..." -ForegroundColor Cyan
    Write-Host "[DEBUG] Output directory: $OutDir" -ForegroundColor DarkCyan

    if (!(Test-Path $OutDir)) {
        New-Item -ItemType Directory -Path $OutDir | Out-Null
    }

    # -------------------------------------------------
    # Load Helpers and Private Modules
    # -------------------------------------------------
    $helpersPath = Join-Path $PSScriptRoot "..\Private\Helpers"
    if (Test-Path $helpersPath) {
        Get-ChildItem $helpersPath -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    }

    $privatePath = Join-Path $PSScriptRoot "..\Private"
    if (Test-Path $privatePath) {
        Get-ChildItem $privatePath -Filter "Get-*.ps1" | ForEach-Object { . $_.FullName }
    }

    # -------------------------------------------------
    # Modules
    # -------------------------------------------------
    $modules = @{
        HostSummary       = "Get-HostSummary"
        Services          = "Get-LocalServices"
        Ports             = "Get-ListeningPorts"
        Autostart         = "Get-Autostart"
        FirewallRules     = "Get-FirewallRules"
        ScheduledTasks    = "Get-ScheduledTasks"
        Drivers           = "Get-Drivers"
        BrowserExtensions = "Get-BrowserExtensions"
    }

    if ($Include) {
        $modules = $modules.GetEnumerator() | Where-Object { $Include -contains $_.Key }
    }

    # -------------------------------------------------
    # Run Enumeration
    # -------------------------------------------------
    $results = @{}
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    foreach ($mod in $modules.Keys) {
        Write-Host "[*] Running $mod enumeration..." -ForegroundColor Yellow
        try {
            $fn = Get-Command $modules[$mod] -ErrorAction Stop
            $data = & $fn
            $results[$mod] = $data
            Write-Host "    -> Collected $($data.Count) items." -ForegroundColor Green
        }
        catch {
            Write-Warning ("[-] Failed {0}: {1}" -f $mod, $_)
            $results[$mod] = @()
        }
    }

    $timer.Stop()
    Write-Host "`n[SUCCESS] Enumeration completed in $([math]::Round($timer.Elapsed.TotalSeconds,2))s" -ForegroundColor Cyan

    # -------------------------------------------------
    # EXPORT RESULTS
    # -------------------------------------------------
    Write-Host "[+] Exporting results..." -ForegroundColor Magenta

    $jsonOut = Export-ToJson `
        -Data $results `
        -OutFile (Join-Path $OutDir "tempest_index.json") `
        -Depth 8

    $csvOuts = Export-ToCsv -Report $results -OutDir $OutDir -FlattenCombined

    $htmlOut = Build-HtmlReport `
        -Report $results `
        -OutFile (Join-Path $OutDir "dashboard.html") `
        -Title "T.E.M.P.E.S.T. Report"

    # -------------------------------------------------
    # PATH RESOLUTION (ABSOLUTE)
    # -------------------------------------------------
    $projectRoot  = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    $analysisDir  = Join-Path $projectRoot "analysis"
    $maliciousDir = Join-Path $projectRoot "malicious"
    $modelRoot    = Join-Path $analysisDir "models"

    New-Item -ItemType Directory -Path $modelRoot -Force | Out-Null

    # -------------------------------------------------
    # PORTS ML ANALYSIS (FIXED)
    # -------------------------------------------------
    $portsCsv      = (Resolve-Path (Join-Path $OutDir "Ports.csv")).Path
    $portsTrainCsv = (Resolve-Path (Join-Path $maliciousDir "fakePorts.csv")).Path
    $portsPy       = (Resolve-Path (Join-Path $analysisDir "ports_risk_pipeline.py")).Path
    $portsModelDir = Join-Path $modelRoot "ports"

    if (Test-Path $portsCsv) {
        New-Item -ItemType Directory -Path $portsModelDir -Force | Out-Null

        if (!(Test-Path (Join-Path $portsModelDir "ports_xgb.model"))) {
            Write-Host "[AI] Training Ports model..." -ForegroundColor Yellow
            python $portsPy train --data "$portsTrainCsv" --model_dir "$portsModelDir"
        }

        Write-Host "[AI] Scoring Ports..." -ForegroundColor Yellow
        python $portsPy score `
            --data "$portsCsv" `
            --model_dir "$portsModelDir" `
            --output "$(Join-Path $OutDir 'Ports_with_risk.csv')"

        Write-Host "[AI] Ports ML complete." -ForegroundColor Green
    }

    # -------------------------------------------------
    # SERVICES ML ANALYSIS (FIXED)
    # -------------------------------------------------
    $servicesCsv      = (Resolve-Path (Join-Path $OutDir "Services.csv")).Path
    $servicesTrainCsv = (Resolve-Path (Join-Path $maliciousDir "fakeServices.csv")).Path
    $servicesPy       = (Resolve-Path (Join-Path $analysisDir "services_risk_pipeline.py")).Path
    $servicesModelDir = Join-Path $modelRoot "services"

    if (Test-Path $servicesCsv) {
        New-Item -ItemType Directory -Path $servicesModelDir -Force | Out-Null

        if (!(Test-Path (Join-Path $servicesModelDir "services_xgb.model"))) {
            Write-Host "[AI] Training Services model..." -ForegroundColor Yellow
            python $servicesPy train --data "$servicesTrainCsv" --model_dir "$servicesModelDir"
        }

        Write-Host "[AI] Scoring Services..." -ForegroundColor Yellow
        python $servicesPy score `
            --data "$servicesCsv" `
            --model_dir "$servicesModelDir"

        Write-Host "[AI] Services ML complete." -ForegroundColor Green
    }

    # -------------------------------------------------
    # FINAL OUTPUT
    # -------------------------------------------------
    Write-Host "`nReports saved to $OutDir" -ForegroundColor Green
    $csvOuts | ForEach-Object { Write-Host "  - $(Split-Path $_ -Leaf)" }
    Write-Host "  - dashboard.html"
    Write-Host "  - Ports_with_risk.csv"
    Write-Host "  - Services_with_risk.csv"

    return $results
}
