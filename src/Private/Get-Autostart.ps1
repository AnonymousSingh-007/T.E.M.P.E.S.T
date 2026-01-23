function Get-Autostart {

    $results = @()

    Write-Diag "Autostart: querying CIM startup commands"

    try {
        $cim = Get-CimInstance Win32_StartupCommand -ErrorAction Stop
        foreach ($item in $cim) {
            $results += [pscustomobject]@{
                Name     = $item.Name
                Command  = $item.Command
                Location = $item.Location
                User     = $item.User
                Source   = "CIM"
            }
        }
    }
    catch {
        Write-Diag "Autostart CIM failed: $_" "WARN"
    }

    Write-Diag "Autostart: querying HKLM Run keys"

    $runKeys = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    )

    foreach ($rk in $runKeys) {
        try {
            if (Test-Path $rk) {
                Get-ItemProperty $rk | ForEach-Object {
                    $_.PSObject.Properties |
                    Where-Object { $_.Name -notmatch '^PS' } |
                    ForEach-Object {
                        $results += [pscustomobject]@{
                            Name     = $_.Name
                            Command  = $_.Value
                            Location = $rk
                            User     = $env:USERNAME
                            Source   = "Registry"
                        }
                    }
                }
            }
        }
        catch {
            Write-Diag "Autostart registry failed: $_" "WARN"
        }
    }

    Write-Diag "Autostart: returning $($results.Count) items"
    return $results
}
