function Build-HtmlReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Report,

        [Parameter(Mandatory)]
        [string]$OutFile,

        [string]$Title = "T.E.M.P.E.S.T. Report"
    )

    Add-Type -AssemblyName System.Web
    function Encode($v) { [System.Web.HttpUtility]::HtmlEncode([string]$v) }

    function Get-RiskClass($value) {
        if ($null -eq $value) { return "" }
        if ($value -ge 80) { return "risk-critical" }
        elseif ($value -ge 60) { return "risk-high" }
        elseif ($value -ge 40) { return "risk-medium" }
        else { return "risk-low" }
    }

    $sb = New-Object System.Text.StringBuilder

    # -------------------------------
    # HTML + CSS
    # -------------------------------
    $null = $sb.AppendLine(@"
<!DOCTYPE html>
<html>
<head>
<meta charset='utf-8'>
<title>$Title</title>
<style>
    body {
        font-family: Segoe UI, Consolas, monospace;
        background: #0b0f14;
        color: #d0d6e0;
        padding: 20px;
    }

    h1 { margin-bottom: 10px; }

    .section {
        margin-bottom: 25px;
        border: 1px solid #1f2937;
        border-radius: 6px;
        overflow: hidden;
        background: #0f1622;
    }

    .section-header {
        padding: 10px 14px;
        background: #111827;
        cursor: pointer;
        font-weight: 600;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .section-header:hover { background: #1f2937; }

    .section-header span {
        color: #9ca3af;
        font-size: 12px;
    }

    .section-content { display: none; padding: 10px; }
    .section.open .section-content { display: block; }

    .table-wrapper {
        max-height: 450px;
        overflow: auto;
        border: 1px solid #1f2937;
        border-radius: 4px;
    }

    table {
        width: 100%;
        border-collapse: collapse;
        font-size: 12px;
    }

    th {
        position: sticky;
        top: 0;
        background: #020617;
        color: #7dd3fc;
        text-align: left;
        padding: 6px;
        border-bottom: 1px solid #334155;
        z-index: 2;
    }

    td {
        padding: 6px;
        border-bottom: 1px solid #1e293b;
        vertical-align: top;
    }

    tr:hover td { background: #020617; }

    /* Risk coloring */
    .risk-critical { background-color: #7f1d1d !important; color: #fee2e2; font-weight: bold; }
    .risk-high     { background-color: #78350f !important; color: #ffedd5; }
    .risk-medium   { background-color: #713f12 !important; color: #fef9c3; }
    .risk-low      { background-color: #064e3b !important; color: #d1fae5; }

    em { color: #9ca3af; }

    footer {
        margin-top: 40px;
        font-size: 11px;
        color: #6b7280;
    }
</style>

<script>
function toggleSection(id) {
    document.getElementById(id).classList.toggle('open');
}
</script>
</head>
<body>
<h1>$Title</h1>
<hr/>
"@)

    # -------------------------------
    # SECTIONS
    # -------------------------------
    $i = 0
    foreach ($key in $Report.Keys) {
        $items = @($Report[$key])
        $sectionId = "section_$i"
        $count = $items.Count

        $null = $sb.AppendLine("<div class='section' id='$sectionId'>")
        $null = $sb.AppendLine("<div class='section-header' onclick=`"toggleSection('$sectionId')`">")
        $null = $sb.AppendLine("<div>$key</div>")
        $null = $sb.AppendLine("<span>$count items</span>")
        $null = $sb.AppendLine("</div>")
        $null = $sb.AppendLine("<div class='section-content'>")

        if ($count -eq 0) {
            $null = $sb.AppendLine("<em>No data</em>")
        }
        else {
            $cols = $items[0].PSObject.Properties.Name

            # Detect score column
            $scoreCol = $cols | Where-Object { $_ -match 'RiskScore|AnomalyScore|Score' } | Select-Object -First 1

            if ($scoreCol) {
                $items = $items | Sort-Object { [double]($_.$scoreCol) } -Descending
            }

            $null = $sb.AppendLine("<div class='table-wrapper'><table>")
            $null = $sb.AppendLine("<thead><tr>")
            foreach ($c in $cols) {
                $null = $sb.AppendLine("<th>$(Encode $c)</th>")
            }
            $null = $sb.AppendLine("</tr></thead><tbody>")

            foreach ($item in $items) {
                $null = $sb.AppendLine("<tr>")
                foreach ($c in $cols) {
                    $value = $item.$c
                    $cls = ""

                    if ($c -eq $scoreCol) {
                        $cls = Get-RiskClass ([double]$value)
                    }

                    $null = $sb.AppendLine("<td class='$cls'>$(Encode $value)</td>")
                }
                $null = $sb.AppendLine("</tr>")
            }

            $null = $sb.AppendLine("</tbody></table></div>")
        }

        $null = $sb.AppendLine("</div></div>")
        $i++
    }

    # -------------------------------
    # FOOTER
    # -------------------------------
    $null = $sb.AppendLine(@"
<footer>
Generated by T.E.M.P.E.S.T • $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
</footer>
</body>
</html>
"@)

    $sb.ToString() | Out-File -Encoding UTF8 -Force $OutFile
    Write-Host "[OK] HTML report generated → $OutFile" -ForegroundColor Green
}
