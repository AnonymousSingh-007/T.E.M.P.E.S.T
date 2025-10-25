function Get-ListeningPorts {
    <#
    .SYNOPSIS
        Enumerates active TCP/UDP listening ports on the local host.

    .DESCRIPTION
        Collects information about listening network ports, including the process ID,
        owning process name, protocol, local address, and port. Useful for identifying
        network-exposed services and potential attack surfaces.

    .OUTPUTS
        [PSCustomObject] with:
        - Protocol
        - LocalAddress
        - LocalPort
        - ProcessId
        - ProcessName
    #>

    [CmdletBinding()]
    param ()

    Write-Verbose "[+] Enumerating listening ports..."

    try {
        $netstat = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
            [PSCustomObject]@{
                Protocol     = 'TCP'
                LocalAddress = $_.LocalAddress
                LocalPort    = $_.LocalPort
                ProcessId    = $_.OwningProcess
                ProcessName  = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName
            }
        }

        $udp = Get-NetUDPEndpoint -ErrorAction SilentlyContinue | ForEach-Object {
            [PSCustomObject]@{
                Protocol     = 'UDP'
                LocalAddress = $_.LocalAddress
                LocalPort    = $_.LocalPort
                ProcessId    = $_.OwningProcess
                ProcessName  = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName
            }
        }

        $ports = $netstat + $udp
        Write-Verbose "[+] Retrieved $($ports.Count) listening ports."
        return $ports
    }
    catch {
        Write-Warning "[-] Failed to enumerate ports: $_"
        return @()
    }
}
