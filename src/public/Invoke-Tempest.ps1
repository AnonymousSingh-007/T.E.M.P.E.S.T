function Invoke-Tempest {
    [CmdletBinding()]
    param (
        [string]$OutDir = (Join-Path (Get-Location) "output")
    )

    $start = Get-Date
    Write-Host "[INFO] Starting T.E.M.P.E.S.T"

    # -------------------------------------------------
    # Resolve paths (THIS WAS THE CORE BUG)
    # -------------------------------------------------
    $basePath   = $PSScriptRoot
    $helperPath = Join-Path $basePath "..\Private\Helpers"
    $modulePath = Join-Path $basePath "..\Private"
    $htmlFile   = Join-Path $basePath "..\Private\Helpers\Build-HtmlReport.ps1"

    # -------------------------------------------------
    # Load helpers FIRST (Write-Diag lives here)
    # -------------------------------------------------
    if (-not (Test-Path $helperPath)) {
        throw "Helpers directory not found: $helperPath"
    }

    Get-ChildItem $helperPath -Filter *.ps1 | ForEach-Object {
        . $_.FullName
    }

    Write-Diag "Helpers loaded"

    # -------------------------------------------------
    # Load HTML builder
    # -------------------------------------------------
    if (-not (Test-Path $htmlFile)) {
        throw "Build-HtmlReport.ps1 not found"
    }

    . $htmlFile
    Write-Diag "HTML report builder loaded"

    # -------------------------------------------------
    # Load modules
    # -------------------------------------------------
    if (-not (Test-Path $modulePath)) {
        throw "Modules directory not found: $modulePath"
    }

    Get-ChildItem $modulePath -Filter *.ps1 | ForEach-Object {
        . $_.FullName
        Write-Diag "Loaded module: $($_.Name)"
    }

    Write-Diag "All modules loaded"

    # -------------------------------------------------
    # Output directory
    # -------------------------------------------------
    if (-not (Test-Path $OutDir)) {
        New-Item -ItemType Directory -Path $OutDir | Out-Null
    }

    Write-Diag "Output directory: $OutDir"

    # -------------------------------------------------
    # Module execution map
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
        $sw = [Diagnostics.Stopwatch]::StartNew()

        try {
            Write-Diag "Starting module $($m.Key)"
            $data = & $m.Value
            $Report[$m.Key] = @($data)
            Write-Diag "$($m.Key): collected $(@($data).Count) items"
        }
        catch {
            Write-Diag "$($m.Key) failed: $_" "ERROR"
            $Report[$m.Key] = @()
        }

        $csv = Join-Path $OutDir "$($m.Key).csv"
        $Report[$m.Key] | Export-Csv -NoTypeInformation -Encoding UTF8 -Force $csv
        Write-Host "    [OK] Exported $($m.Key).csv"
        Write-Diag "$($m.Key): CSV exported"

        $sw.Stop()
        Write-Diag "$($m.Key) finished in $([math]::Round($sw.Elapsed.TotalSeconds,2))s"
    }

    # -------------------------------------------------
    # Combined CSV
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
    # JSON
    # -------------------------------------------------
    $jsonFile = Join-Path $OutDir "tempest_report.json"
    $Report | ConvertTo-Json -Depth 5 | Out-File -Encoding UTF8 -Force $jsonFile
    Write-Diag "JSON written"

    # -------------------------------------------------
    # HTML
    # -------------------------------------------------
    $htmlOut = Join-Path $OutDir "tempest_report.html"
    Build-HtmlReport -Report $Report -OutFile $htmlOut -Title "T.E.M.P.E.S.T. System Enumeration"

    # -------------------------------------------------
    # Done
    # -------------------------------------------------
    $elapsed = (Get-Date) - $start
    Write-Host "`n[SUCCESS] Completed in $([math]::Round($elapsed.TotalSeconds,2))s" -ForegroundColor Green
    Write-Diag "Run complete"
}
