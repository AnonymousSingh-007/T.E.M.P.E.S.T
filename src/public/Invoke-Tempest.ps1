function Invoke-Tempest {
    [CmdletBinding()]
    param (
        [string]$OutDir = ".\output",
        [string[]]$Include
    )

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    Write-Host "`n[INFO] Initializing T.E.M.P.E.S.T. enumeration..." -ForegroundColor Cyan

    # -------------------------------------------------
    # NORMALIZE OUTPUT DIRECTORY (CRITICAL FIX)
    # -------------------------------------------------
    $OutDir = Resolve-Path (New-Item -ItemType Directory -Force -Path $OutDir)
    $OutDir = $OutDir.Path
    Write-Host "[DEBUG] Output directory: $OutDir" -ForegroundColor DarkCyan

    # -------------------------------------------------
    # LOAD HELPERS / PRIVATE MODULES
    # -------------------------------------------------
    $helpersPath = Resolve-Path (Join-Path $PSScriptRoot "..\Private\Helpers")
    foreach ($file in Get-ChildItem $helpersPath -Filter "*.ps1" -File) {
        . $file.FullName
    }

    $privatePath = Resolve-Path (Join-Path $PSScriptRoot "..\Private")
    foreach ($file in Get-ChildItem $privatePath -Filter "Get-*.ps1" -File) {
        . $file.FullName
    }

    # -------------------------------------------------
    # MODULE REGISTRY (ORDERED)
    # -------------------------------------------------
    $modules = [ordered]@{
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
        $modules = [ordered]@{}
        foreach ($k in $Include) {
            if ($modules.Contains($k)) {
                $modules[$k] = $modules[$k]
            }
        }
    }

    # -------------------------------------------------
    # RESULTS (IN-MEMORY, SAFE)
    # -------------------------------------------------
    $results = @{}

    # -------------------------------------------------
    # JSON STREAM SETUP (SECONDARY OUTPUT)
    # -------------------------------------------------
    $jsonPath = Join-Path $OutDir "tempest_index.json"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $jsonStream = [System.IO.StreamWriter]::new($jsonPath, $false, $utf8NoBom)
    $jsonStream.WriteLine("{")

    $moduleIndex = 0
    $moduleCount = $modules.Count
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    foreach ($mod in $modules.Keys) {
        $moduleIndex++
        Write-Host "[*] Running $mod enumeration..." -ForegroundColor Yellow

        try {
            $fn = $modules[$mod]
            if (-not (Get-Command $fn -ErrorAction SilentlyContinue)) {
                throw "Function $fn not loaded"
            }

            # ---------------- COLLECT ----------------
            $data = @(& $fn)
            Write-Host "    -> Collected $($data.Count) items." -ForegroundColor Green

            # store in memory (Option A)
            $results[$mod] = $data

            # ---------------- STREAM JSON ----------------
            $jsonStream.Write("  `"$mod`": [")

            $first = $true
            foreach ($item in $data) {
                if (-not $first) { $jsonStream.Write(",") }
                $first = $false
                $jsonStream.Write(
                    ($item | ConvertTo-Json -Depth 10 -Compress)
                )
            }

            $jsonStream.Write("]")
            if ($moduleIndex -lt $moduleCount) { $jsonStream.WriteLine(",") }
            else { $jsonStream.WriteLine() }

            $jsonStream.Flush()

            # ---------------- CSV (MODULE ONLY) ----------------
            Export-ToCsv `
                -Report @{ $mod = $data } `
                -OutDir $OutDir `
                -FlattenCombined | Out-Null
        }
        catch {
            Write-Warning ("[-] Failed {0}: {1}" -f $mod, $_)
        }
        finally {
            # HARD RELEASE
            $data = $null
            [GC]::Collect()
        }
    }

    # ---------------- CLOSE JSON ----------------
    $timer.Stop()
    $jsonStream.WriteLine("}")
    $jsonStream.Close()

    Write-Host "`n[SUCCESS] Enumeration completed in $([math]::Round($timer.Elapsed.TotalSeconds,2))s" -ForegroundColor Cyan
    Write-Host "[OK] JSON index saved: $jsonPath" -ForegroundColor Green

    # -------------------------------------------------
    # HTML REPORT (CORRECT PARAMS)
    # -------------------------------------------------
    if (Get-Command Build-HtmlReport -ErrorAction SilentlyContinue) {
        Build-HtmlReport `
            -Report $results `
            -OutFile (Join-Path $OutDir "dashboard.html") | Out-Null
    }

    Write-Host "`nReports saved to $OutDir" -ForegroundColor Green
    Write-Host "  - tempest_index.json"
    Write-Host "  - dashboard.html"
}
