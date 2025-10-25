function Get-LocalServices {
    <#
    .SYNOPSIS
        Enumerates all local Windows services.

    .DESCRIPTION
        Retrieves information on installed Windows services including their name, display name,
        status, start mode, binary path, and the user account under which each service runs.
        Designed for T.E.M.P.E.S.T. enumeration and exported as structured data for analysis.

    .OUTPUTS
        [PSCustomObject] with:
        - Name
        - DisplayName
        - Status
        - StartMode
        - PathName
        - User
        - Description
        - ServiceType

    .EXAMPLE
        Get-LocalServices | Format-Table -AutoSize
    #>

    [CmdletBinding()]
    param ()

    Write-Verbose "[+] Enumerating local Windows services..."

    try {
        $services = Get-CimInstance -ClassName Win32_Service -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Name         = $_.Name
                DisplayName  = $_.DisplayName
                Status       = $_.State
                StartMode    = $_.StartMode
                PathName     = $_.PathName
                User         = $_.StartName
                Description  = $_.Description
                ServiceType  = $_.ServiceType
            }
        }

        Write-Verbose "[+] Retrieved $($services.Count) services."
        return $services
    }
    catch {
        Write-Warning "[-] Failed to enumerate services: $_"
        return @()
    }
}
