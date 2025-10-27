function Get-HostSummary {
    <#
    .SYNOPSIS
        Gathers high-level system information.
    #>

    [CmdletBinding()]
    param ()

    Write-Verbose "[+] Gathering host summary information..."

    $os  = Get-CimInstance Win32_OperatingSystem
    $sys = Get-CimInstance Win32_ComputerSystem

    $info = [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        OS           = $os.Caption
        Version      = $os.Version
        Architecture = $env:PROCESSOR_ARCHITECTURE
        Uptime       = (Get-Date) - $os.LastBootUpTime
        User         = $env:USERNAME
        Domain       = $sys.Domain
    }

    ,$info  
}
