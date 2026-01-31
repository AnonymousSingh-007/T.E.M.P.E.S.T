function Invoke-Tempest {
    [CmdletBinding()]
    param (
        [string]$OutDir = (Join-Path (Get-Location) "output")
    )

    $start = Get-Date
    Write-Host "[INFO] Starting T.E.M.P.E.S.T"

    # -------------------------------------------------
    # Resolve paths
    # -------------------------------------------------
    $basePath     = $PSScriptRoot
    $helperPath   = Join-Path $basePath "..\Private\Helpers"
    $modulePath   = Join-Path $basePath "..\Private"
    $htmlFile     = Join-Path $basePath "..\Private\Helpers\Build-HtmlReport.ps1"
    $analysisPath = Join-Path $basePath "..\..\analysis\anomaly"

    # -------------------------------------------------
    # Load helpers & modules
    # -------------------------------------------------
    Get-ChildItem $helperPath -Filter *.ps1 | ForEach-Object { . $_.FullName }
    . $htmlFile
    Get-ChildItem $modulePath -Filter *.ps1 | ForEach-Object { . $_.FullName }

    Write-Diag "Helpers and modules loaded"

    # -------------------------------------------------
    # Output directory
    # -------------------------------------------------
    if (-not (Test-Path $OutDir)) {
        New-Item -ItemType Directory -Path $OutDir | Out-Null
    }

    Write-Diag "Output directory: $OutDir"

    # -------------------------------------------------
    # Force venv Python
    # -------------------------------------------------
    $PythonExe = Join-Path (Get-Location) ".venv\Scripts\python.exe"

    if (-not (Test-Path $PythonExe)) {
        Write-Diag "Python virtual environment not found; ML disabled" "WARN"
        $PythonExe = $null
    }
    else {
        Write-Diag "Using venv Python: $PythonExe"
    }

    # -------------------------------------------------
    # Run collection modules
    # -------------------------------------------------
    $Report = @{}

    $modules = @{
        HostSummary    = { Get-HostSummary }
        Services       = { Get-LocalServices }
        Ports          = { Get-ListeningPorts }
        Autostart      = { Get-Autostart }
        FirewallRules  = { Get-FirewallRules }
        ScheduledTasks = { Get-ScheduledTasks }
    }

    foreach ($m in $modules.GetEnumerator()) {
        Write-Host "[*] Running $($m.Key)"

        try {
            $data = & $m.Value
            $Report[$m.Key] = @($data)

            $csv = Join-Path $OutDir "$($m.Key).csv"
            $Report[$m.Key] | Export-Csv -NoTypeInformation -Encoding UTF8 -Force $csv

            Write-Host "    [OK] Exported $($m.Key).csv"
            Write-Diag "$($m.Key): collected $(@($data).Count) items"
        }
        catch {
            Write-Diag "$($m.Key) failed: $_" "ERROR"
            $Report[$m.Key] = @()
        }
    }

    # -------------------------------------------------
    # ML Anomaly Detection (Ports, Services, Autostart)
    # -------------------------------------------------
    if ($PythonExe) {

        $mlJobs = @(
            @{
                Name   = "Ports"
                Input  = "Ports.csv"
                Output = "Ports_with_anomaly.csv"
                Script = "ports_anomaly.py"
            },
            @{
                Name   = "Services"
                Input  = "Services.csv"
                Output = "Services_with_anomaly.csv"
                Script = "services_anomaly.py"
            },
            @{
                Name   = "Autostart"
                Input  = "Autostart.csv"
                Output = "Autostart_with_anomaly.csv"
                Script = "autostart_anomaly.py"
            }
        )

        foreach ($job in $mlJobs) {

            $inputCsv  = Join-Path $OutDir $job.Input
            $outputCsv = Join-Path $OutDir $job.Output
            $scriptPy  = Join-Path $analysisPath $job.Script

            if ((Test-Path $inputCsv) -and (Test-Path $scriptPy)) {
                Write-Host "[*] Running $($job.Name) anomaly detection"

                & $PythonExe $scriptPy --input $inputCsv --output $outputCsv

                if ($LASTEXITCODE -eq 0 -and (Test-Path $outputCsv)) {
                    Write-Diag "$($job.Name) anomaly analysis complete"

                    # 🔑 CRITICAL FIX: Re-import scored CSV into Report
                    $Report[$job.Name] = Import-Csv $outputCsv
                }
                else {
                    Write-Diag "$($job.Name) anomaly analysis failed" "ERROR"
                }
            }
            else {
                Write-Diag "$($job.Name) ML skipped (missing CSV or script)" "WARN"
            }
        }
    }

    # -------------------------------------------------
    # Combined CSV (post-ML)
    # -------------------------------------------------
    $combined = foreach ($k in $Report.Keys) {
        foreach ($row in $Report[$k]) {
            $row | Add-Member Category $k -Force
            $row
        }
    }

    $combinedCsv = Join-Path $OutDir "tempest_combined.csv"
    $combined | Export-Csv -NoTypeInformation -Encoding UTF8 -Force $combinedCsv
    Write-Diag "Combined CSV exported"

    # -------------------------------------------------
    # JSON + HTML
    # -------------------------------------------------
    $jsonFile = Join-Path $OutDir "tempest_report.json"
    $Report | ConvertTo-Json -Depth 5 | Out-File -Encoding UTF8 -Force $jsonFile
    Write-Diag "JSON written"

    $htmlOut = Join-Path $OutDir "tempest_report.html"
    Build-HtmlReport -Report $Report -OutFile $htmlOut -Title "T.E.M.P.E.S.T. System Enumeration"

    # -------------------------------------------------
    # Done
    # -------------------------------------------------
    $elapsed = (Get-Date) - $start
    Write-Host "`n[SUCCESS] Completed in $([math]::Round($elapsed.TotalSeconds,2))s" -ForegroundColor Green
    Write-Diag "Run complete"
}
