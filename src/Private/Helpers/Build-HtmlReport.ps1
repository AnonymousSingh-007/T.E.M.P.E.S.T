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

    $sb = New-Object System.Text.StringBuilder

    $null = $sb.AppendLine("<!DOCTYPE html>")
    $null = $sb.AppendLine("<html><head><meta charset='utf-8'>")
    $null = $sb.AppendLine("<title>$Title</title>")
    $null = $sb.AppendLine("<style>")
    $null = $sb.AppendLine("body{font-family:Segoe UI,Consolas;background:#0b0f14;color:#d0d6e0;padding:20px}")
    $null = $sb.AppendLine("table{width:100%;border-collapse:collapse;font-size:13px}")
    $null = $sb.AppendLine("th,td{padding:6px;border-bottom:1px solid #333}")
    $null = $sb.AppendLine("th{color:#7a8599;text-align:left}")
    $null = $sb.AppendLine("</style></head><body>")
    $null = $sb.AppendLine("<h1>$Title</h1><hr/>")

    foreach ($key in $Report.Keys) {
        $items = @($Report[$key])

        $null = $sb.AppendLine("<h2>$key ($($items.Count))</h2>")

        if ($items.Count -eq 0) {
            $null = $sb.AppendLine("<em>No data</em>")
            continue
        }

        $cols = $items[0].PSObject.Properties.Name
        $null = $sb.AppendLine("<table><tr>")

        foreach ($c in $cols) {
            $null = $sb.AppendLine("<th>$(Encode $c)</th>")
        }

        $null = $sb.AppendLine("</tr>")

        foreach ($item in $items) {
            $null = $sb.AppendLine("<tr>")
            foreach ($c in $cols) {
                $null = $sb.AppendLine("<td>$(Encode $item.$c)</td>")
            }
            $null = $sb.AppendLine("</tr>")
        }

        $null = $sb.AppendLine("</table><br/>")
    }

    $null = $sb.AppendLine("</body></html>")

    $sb.ToString() | Out-File -Encoding UTF8 -Force $OutFile
    Write-Host "[OK] HTML report generated → $OutFile" -ForegroundColor Green
}
