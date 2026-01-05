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

    # ----------------------------
    # Aggregate risk data
    # ----------------------------
    $allItems = foreach ($k in $Report.Keys) { @($Report[$k]) }
    $allItems = @($allItems | Where-Object { $_ })

    $riskItems = $allItems | Where-Object {
        $_.PSObject.Properties.Name -contains "RiskScore"
    }

    $highRisk = ($riskItems | Where-Object { [double]$_.RiskScore -ge 80 }).Count
    $medRisk  = ($riskItems | Where-Object { [double]$_.RiskScore -ge 50 -and [double]$_.RiskScore -lt 80 }).Count
    $lowRisk  = ($riskItems | Where-Object { [double]$_.RiskScore -gt 0 -and [double]$_.RiskScore -lt 50 }).Count

    $generated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $hostname  = $env:COMPUTERNAME

    # ----------------------------
    # HTML Header + Styles
    # ----------------------------
    $html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>$Title Tactical Console</title>
<style>
:root {
    --bg: #0b0f14;
    --panel: #111722;
    --panel-border: #1f2a3a;
    --text: #d0d6e0;
    --muted: #7a8599;
    --accent: #7aa2ff;
    --danger: #ff5f5f;
    --warn: #f0c36c;
    --ok: #63e6be;
}
* { box-sizing: border-box; }
body { margin:0; padding:24px; background: radial-gradient(circle at top,#10151f,var(--bg)); color:var(--text); font-family:"Segoe UI",Consolas,monospace; }
h1 { font-size:34px; letter-spacing:2px; margin:0; }
.sub { color:var(--muted); margin-top:6px; font-size:13px; }
hr { border:none; border-top:1px solid var(--panel-border); margin:28px 0; }
.panel { background: linear-gradient(180deg,#121a27,var(--panel)); border:1px solid var(--panel-border); border-radius:10px; padding:18px; box-shadow:0 0 0 1px rgba(255,255,255,0.02); }
.grid { display:grid; gap:18px; }
.grid-3 { grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); }
.meter { height:8px; background:#1a2233; border-radius:4px; overflow:hidden; margin-top:10px; }
.meter>div { height:100%; transition:width 1.2s ease; }
.high { background: var(--danger); }
.med { background: var(--warn); }
.low { background: var(--ok); }
table { width:100%; border-collapse:collapse; font-size:13px; }
th { text-align:left; color:var(--muted); font-weight:500; border-bottom:1px solid var(--panel-border); padding:8px; position:sticky; top:0; background:#0e1420; }
td { padding:8px; border-bottom:1px solid #151c2b; }
tr:hover { background: rgba(122,162,255,0.05); }
.risk-high { box-shadow: inset 4px 0 var(--danger); }
.risk-med { box-shadow: inset 4px 0 var(--warn); }
.risk-low { box-shadow: inset 4px 0 var(--ok); }
.section { cursor:pointer; user-select:none; margin-bottom:8px; }
.section span { color: var(--muted); font-size:12px; }
.content { overflow:hidden; transition:max-height 0.6s ease, opacity 0.4s ease; }
.hidden { max-height:0; opacity:0; }
.fade-in { animation: fade 0.8s ease forwards; }
@keyframes fade { from { opacity:0; transform:translateY(6px); } to { opacity:1; transform:none; } }
</style>
<script>
function toggle(id){ document.getElementById(id).classList.toggle("hidden"); }
</script>
</head>
<body>

<div class="panel fade-in">
<h1>$Title</h1>
<div class="sub">LOCAL ATTACK SURFACE CONSOLE</div>
<div class="sub">Host: $hostname · Generated: $generated</div>
</div>

<hr/>

<!-- RISK OVERVIEW -->
<div class="grid grid-3 fade-in">
<div class="panel"><strong>HIGH RISK</strong> ($highRisk)<div class="meter"><div class="high" style="width: $([math]::Min(100,$highRisk*10))%"></div></div></div>
<div class="panel"><strong>MEDIUM RISK</strong> ($medRisk)<div class="meter"><div class="med" style="width: $([math]::Min(100,$medRisk*10))%"></div></div></div>
<div class="panel"><strong>LOW RISK</strong> ($lowRisk)<div class="meter"><div class="low" style="width: $([math]::Min(100,$lowRisk*10))%"></div></div></div>
</div>

<hr/>
"@

    # ----------------------------
    # Sections
    # ----------------------------
    foreach ($key in $Report.Keys) {
        $items = @($Report[$key])
        $secId = "sec_" + ([guid]::NewGuid().ToString("N"))

        $html += "<div class='panel fade-in'>"
        $html += "<div class='section' onclick=`"toggle('$secId')`"><strong>$(Encode $key)</strong> <span>($($items.Count))</span></div>"
        $html += "<div id='$secId' class='content'>"

        if ($items.Count -gt 0) {
            $cols = $items[0].PSObject.Properties.Name
            $html += "<table><thead><tr>"
            foreach ($c in $cols) { $html += "<th>$(Encode $c)</th>" }
            if ($cols -contains "RiskScore") { $html += "<th>Risk Level</th>" }
            $html += "</tr></thead><tbody>"

            foreach ($item in $items) {
                $cls = ""
                $riskText = ""
                if ($item.PSObject.Properties.Name -contains "RiskScore") {
                    $r = [double]$item.RiskScore
                    if ($r -ge 80) { $cls = "risk-high"; $riskText="High" }
                    elseif ($r -ge 50) { $cls = "risk-med"; $riskText="Medium" }
                    elseif ($r -gt 0) { $cls = "risk-low"; $riskText="Low" }
                }

                $html += "<tr class='$cls'>"
                foreach ($c in $cols) { $html += "<td>$(Encode $item.$c)</td>" }
                if ($riskText) { $html += "<td>$riskText</td>" }
                $html += "</tr>"
            }

            $html += "</tbody></table>"
        }
        else { $html += "<em>No data collected</em>" }

        $html += "</div></div><br/>"
    }

    $html += "</body></html>"

    $html | Out-File -Encoding UTF8 -Force $OutFile
    Write-Host "[OK] Tactical HTML report generated → $OutFile" -ForegroundColor Green
    return $OutFile
}
