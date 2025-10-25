function Get-BrowserExtensions {
    <#
    .SYNOPSIS
        Enumerates installed browser extensions for Chromium-based and Firefox browsers.

    .DESCRIPTION
        Collects basic info on browser extensions found in default install locations
        (Edge, Chrome, Brave, Firefox). Non-invasive, read-only.

    .OUTPUTS
        [PSCustomObject] with:
        - Browser
        - ExtensionName
        - ID
        - Path
    #>

    [CmdletBinding()]
    param ()

    Write-Verbose "[+] Enumerating browser extensions..."

    $results = @()
    $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions"
    $edgePath   = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions"
    $bravePath  = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Extensions"
    $firefoxPath = "$env:APPDATA\Mozilla\Firefox\Profiles"

    foreach ($path in @($chromePath, $edgePath, $bravePath)) {
        if (Test-Path $path) {
            Get-ChildItem -Path $path -Directory | ForEach-Object {
                $results += [PSCustomObject]@{
                    Browser        = (Split-Path $path -Parent | Split-Path -Leaf)
                    ExtensionName  = $_.Name
                    ID             = $_.Name
                    Path           = $_.FullName
                }
            }
        }
    }

    if (Test-Path $firefoxPath) {
        Get-ChildItem -Path $firefoxPath -Directory | ForEach-Object {
            $extJson = Join-Path $_.FullName "extensions.json"
            if (Test-Path $extJson) {
                $json = Get-Content $extJson -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                foreach ($ext in $json.addons) {
                    $results += [PSCustomObject]@{
                        Browser        = 'Firefox'
                        ExtensionName  = $ext.defaultLocale.name
                        ID             = $ext.id
                        Path           = $_.FullName
                    }
                }
            }
        }
    }

    return $results
}
