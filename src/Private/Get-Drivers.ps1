function Get-Drivers {
    <#
    .SYNOPSIS
        Enumerates installed device drivers.

    .DESCRIPTION
        Lists all system drivers with associated company name, version, and file path.

    .OUTPUTS
        [PSCustomObject] with:
        - Name
        - Path
        - Version
        - Company
        - Description
    #>

    [CmdletBinding()]
    param ()

    Write-Verbose "[+] Enumerating installed drivers..."

    try {
        $drivers = Get-CimInstance Win32_SystemDriver | ForEach-Object {
            [PSCustomObject]@{
                Name        = $_.Name
                Path        = $_.PathName
                Version     = $_.Version
                Company     = $_.Manufacturer
                Description = $_.Description
            }
        }

        return $drivers
    }
    catch {
        Write-Warning "[-] Failed to enumerate drivers: $_"
        return @()
    }
}
