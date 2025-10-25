function Get-FirewallRules {
    <#
    .SYNOPSIS
        Enumerates all Windows Defender Firewall rules.

    .DESCRIPTION
        Retrieves firewall rules with their names, enabled state, direction, and associated programs.

    .OUTPUTS
        [PSCustomObject] with:
        - Name
        - Enabled
        - Direction
        - Action
        - Program
        - Profile
    #>

    [CmdletBinding()]
    param ()

    Write-Verbose "[+] Enumerating Windows Firewall rules..."

    try {
        $rules = Get-NetFirewallRule -ErrorAction SilentlyContinue | ForEach-Object {
            $details = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $_ -ErrorAction SilentlyContinue
            [PSCustomObject]@{
                Name       = $_.DisplayName
                Enabled    = $_.Enabled
                Direction  = $_.Direction
                Action     = $_.Action
                Program    = $details.Program
                Profile    = $_.Profile
            }
        }

        return $rules
    }
    catch {
        Write-Warning "[-] Failed to enumerate firewall rules: $_"
        return @()
    }
}
