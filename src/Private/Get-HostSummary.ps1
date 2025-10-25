function Get-HostSummary {
    <#
    .SYNOPSIS
        Gathers high-level system information.

    .DESCRIPTION
        Collects key system metadata like hostname, OS, uptime, architecture, and current user.

    .OUTPUTS
        [PSCustomObject] with:
        - ComputerName
        - OS
        - Version
        - Architecture
        - Uptime
        - User
        - Domain
    #>

    [CmdletBinding()]
    param ()

    Write-Verbose "[+] Gathering host summary information..."

    $os = Get-CimInstance Win32_OperatingSystem
    $sys = Get-CimInstance Win32_ComputerSystem

    [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        OS           = $os.Caption
        Version      = $os.Version
        Architecture = $env:PROCESSOR_ARCHITECTURE
        Uptime       = (Get-Date) - $os.LastBootUpTime
        User         = $env:USERNAME
        Domain       = $sys.Domain
    }
}
