# ==============================
# Script Root
# ==============================
$ScriptRoot = $PSScriptRoot

function Invoke-Tempest {
    [CmdletBinding()]
    param(
        [string]$OutDir = ".\output",
        [string[]]$Include
    )

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Write-Host "`n[INFO] Starting T.E.M.P.E.S.T" -ForegroundColor Cyan

    # ---------------- OUTPUT ----------------
    $OutDir = (New-Item -ItemType Directory -Force -Path $OutDir).FullName

    # ---------------- PATHS ----------------
    $helpersPath = Join-Path $ScriptRoot "..\Private\Helpers"
    $privatePath = Join-Path $ScriptRoot "..\Private"

    if (!(Test-Path $helpersPath)) { throw "Helpers path missing" }
    if (!(Test-Path $privatePath)) { throw "Private path missing" }

    # ---------------- LOAD HELPERS FIRST ----------------
    Get-ChildItem $helpersPath -Filter "*.ps1" | ForEach-Object {
        . $_.FullName
    }

    Write-Diag "Helpers loaded"

    # ---------------- LOAD MODULES ----------------
    Get-ChildItem $privatePath -Filter "Get-*.ps1" | ForEach-Object {
        . $_.FullName
        Write-Diag "Loaded module: $($_.Name)"
    }

    Write-Diag "All modules loaded"
    Write-Diag "Output directory: $OutDir"

    # ---------------- MODULE REGISTRY ----------------
    $allModules = [ordered]@{
        HostSummary    = "Get-HostSummary"
        Services       = "Get-LocalServices"
        Ports          = "Get-ListeningPorts"
        Autostart      = "Get-Autostart"
        FirewallRules  = "Get-FirewallRules"
        ScheduledTasks = "Get-ScheduledTasks"
    }

    if ($Include) {
        $modules = $allModules.GetEnumerator() |
            Where-Object { $Include -contains $_.Key }
    }
    else {
        $modules = $allModules.GetEnumerator()
    }

    if (-not $modules) {
        throw "No valid modules selected"
    }

    # ---------------- RUN ----------------
    $results = @{}
    $globalTimer = [Diagnostics.Stopwatch]::StartNew()

    foreach ($m in $modules) {

        Write-Host "[*] Running $($m.Key)" -ForegroundColor Yellow
        Write-Diag "Starting module $($m.Key)"

        $moduleTimer = [Diagnostics.Stopwatch]::StartNew()

        try {
            if (-not (Get-Command $m.Value -ErrorAction SilentlyContinue)) {
                throw "Function $($m.Value) not loaded"
            }

            # ---------- EXECUTE ----------
            $raw = @(& $m.Value)

            Write-Diag "$($m.Key): collected $($raw.Count) items"

            # ---------- SANITIZE ----------
            if ($m.Key -eq "Autostart") {
                $clean = $raw
            }
            else {
                $clean = foreach ($r in $raw) {
                    Convert-ToPlainObject $r
                }
            }

            $results[$m.Key] = $clean

            Export-ToCsv `
                -Report @{ $m.Key = $clean } `
                -OutDir $OutDir | Out-Null

            Write-Diag "$($m.Key): CSV exported"
        }
        catch {
            Write-Warning "$($m.Key) failed: $_"
            Write-Diag "$($m.Key) error: $_" "ERROR"
        }
        finally {
            $moduleTimer.Stop()
            Write-Diag "$($m.Key) finished in $([math]::Round($moduleTimer.Elapsed.TotalSeconds,2))s"
        }
    }

    # ---------------- COMBINED CSV ----------------
    Export-ToCsv `
        -Report $results `
        -OutDir $OutDir `
        -FlattenCombined | Out-Null

    Write-Diag "Combined CSV exported"

    # ---------------- JSON ----------------
    $jsonPath = Join-Path $OutDir "tempest_index.json"
    $results | ConvertTo-Json -Depth 6 |
        Out-File $jsonPath -Encoding UTF8

    Write-Diag "JSON written"

    $globalTimer.Stop()
    Write-Host "`n[SUCCESS] Completed in $([math]::Round($globalTimer.Elapsed.TotalSeconds,2))s" -ForegroundColor Green
    Write-Diag "Run complete"
}
