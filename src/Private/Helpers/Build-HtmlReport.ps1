function Build-HtmlReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Report,

        [Parameter(Mandatory)]
        [string]$OutFile,

        [string]$Title = "T.E.M.P.E.S.T."
    )

    Add-Type -AssemblyName System.Web
    function Encode($v) { [System.Web.HttpUtility]::HtmlEncode([string]$v) }

    $allItems = foreach ($k in $Report.Keys) { @($Report[$k]) }
    $allItems = @($allItems | Where-Object { $_ })

    $riskItems = $allItems | Where-Object {
        $_.PSObject.Properties.Name -contains "RiskScore"
    }

    $highRisk = ($riskItems | Where-Object { $_.RiskScore -ge 80 }).Count
    $medRisk  = ($riskItems | Where-Object { $_.RiskScore -ge 50 -and $_.RiskScore -lt 80 }).Count
    $lowRisk  = ($riskItems | Where-Object { $_.RiskScore -gt 0 -and $_.RiskScore -lt 50 }).Count

    $generated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $hostname  = $env:COMPUTERNAME

    $html = "<!DOCTYPE html><html><head><meta charset='utf-8'><title>$Title</title></head><body>"
    $html += "<h1>$Title</h1><p>$hostname · $generated</p>"

    foreach ($key in $Report.Keys) {
        $items = @($Report[$key])
        $html += "<h2>$(Encode $key) ($($items.Count))</h2>"

        if ($items.Count -gt 0) {
            $cols = $items[0].PSObject.Properties.Name
            $html += "<table border='1'><tr>"
            foreach ($c in $cols) { $html += "<th>$c</th>" }
            $html += "</tr>"

            foreach ($item in $items) {
                $html += "<tr>"
                foreach ($c in $cols) {
                    $html += "<td>$(Encode $item.$c)</td>"
                }
                $html += "</tr>"
            }
            $html += "</table>"
        }
    }

    $html += "</body></html>"
    $html | Out-File -Encoding UTF8 -Force $OutFile
}
