function Get-Autostart {
    <#
    .SYNOPSIS
        Enumerates programs configured to start automatically on system boot or user logon.

    .DESCRIPTION
        Collects data from Run registry keys and Startup folders for all users.
        Helps detect persistence mechanisms or unwanted software.

    .OUTPUTS
        [PSCustomObject] with:
        - Source
        - KeyPath
        - Name
        - Command
    #>

    [CmdletBinding()]
    param ()

    Write-Verbose "[+] Enumerating autostart entries..."

    $entries = @()
    $runKeys = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    )

    foreach ($key in $runKeys) {
        if (Test-Path $key) {
            $props = Get-ItemProperty -Path $key
            foreach ($name in $props.PSObject.Properties.Name) {
                $entries += [PSCustomObject]@{
                    Source   = 'Registry'
                    KeyPath  = $key
                    Name     = $name
                    Command  = $props.$name
                }
            }
        }
    }

    # Startup folder items
    $startupDirs = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup"
    )

    foreach ($dir in $startupDirs) {
        if (Test-Path $dir) {
            Get-ChildItem -Path $dir -ErrorAction SilentlyContinue | ForEach-Object {
                $entries += [PSCustomObject]@{
                    Source   = 'StartupFolder'
                    KeyPath  = $dir
                    Name     = $_.Name
                    Command  = $_.FullName
                }
            }
        }
    }

    return $entries
}
