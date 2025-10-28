function Build-HtmlReport {
    <#
    .SYNOPSIS
        Builds an interactive HTML dashboard for T.E.M.P.E.S.T. results.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [hashtable]$Report,
        [Parameter(Mandatory=$true)] [string]$OutFile,
        [string]$Title = "T.E.M.P.E.S.T. Report"
    )

    $html = @"
<html>
<head>
<title>$Title</title>
<style>
body { font-family: Consolas, monospace; background-color: #0f111a; color: #ddd; padding: 20px; }
h1 { color: #7ed957; }
h2 { color: #58a6ff; margin-top: 40px; }
table { border-collapse: collapse; width: 100%; margin-bottom: 40px; }
th, td { border: 1px solid #333; padding: 6px 10px; font-size: 13px; }
th { background-color: #1e222e; color: #fff; cursor: pointer; }
tr:nth-child(even) { background-color: #161821; }
</style>
<script>
function sortTable(n, tableId) {
  var table = document.getElementById(tableId);
  var switching = true, dir = "asc", switchcount = 0;
  while (switching) {
    switching = false;
    var rows = table.rows;
    for (var i = 1; i < (rows.length - 1); i++) {
      var shouldSwitch = false;
      var x = rows[i].getElementsByTagName("TD")[n];
      var y = rows[i + 1].getElementsByTagName("TD")[n];
      if (dir == "asc" && x.innerHTML.toLowerCase() > y.innerHTML.toLowerCase()) {
        shouldSwitch = true; break;
      } else if (dir == "desc" && x.innerHTML.toLowerCase() < y.innerHTML.toLowerCase()) {
        shouldSwitch = true; break;
      }
    }
    if (shouldSwitch) {
      rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
      switching = true; switchcount++;
    } else if (switchcount == 0 && dir == "asc") { dir = "desc"; switching = true; }
  }
}
</script>
</head>
<body>
<h1>🛰️ $Title</h1>
<p>Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
"@

    foreach ($key in $Report.Keys) {
        $safeKey = [System.Web.HttpUtility]::HtmlEncode($key)
        $html += "<h2>$safeKey</h2><table id='$safeKey'><tr>"

        if ($Report[$key].Count -gt 0) {
            $columns = $Report[$key][0].PSObject.Properties.Name
            $i = 0
            foreach ($col in $columns) {
                # Use single quotes outside, escape variables properly
                $html += ('<th onclick="sortTable({0}, ''{1}'')">{2}</th>' -f $i, $safeKey, [System.Web.HttpUtility]::HtmlEncode($col))
                $i++
            }
            $html += "</tr>"

            foreach ($item in $Report[$key]) {
                $html += "<tr>"
                foreach ($col in $columns) {
                    $val = [System.Web.HttpUtility]::HtmlEncode($item.$col)
                    $html += "<td>$val</td>"
                }
                $html += "</tr>"
            }
        }
        else {
            $html += "<tr><td><i>No data collected</i></td></tr>"
        }

        $html += "</table>"
    }

    $html += "</body></html>"
    $html | Out-File -Encoding UTF8 -Force -FilePath $OutFile

    Write-Host "    [OK] HTML dashboard generated: $OutFile" -ForegroundColor Green
    return $OutFile
}
