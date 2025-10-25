function Get-ScheduledTasks {
    <#
    .SYNOPSIS
        Enumerates all scheduled tasks on the system.

    .DESCRIPTION
        Lists scheduled tasks with key execution details such as path, trigger, and command.

    .OUTPUTS
        [PSCustomObject] with:
        - TaskName
        - Path
        - State
        - Author
        - Action
        - LastRunTime
        - NextRunTime
    #>

    [CmdletBinding()]
    param ()

    Write-Verbose "[+] Enumerating scheduled tasks..."

    try {
        $tasks = Get-ScheduledTask | ForEach-Object {
            $info = Get-ScheduledTaskInfo -TaskName $_.TaskName -ErrorAction SilentlyContinue
            [PSCustomObject]@{
                TaskName     = $_.TaskName
                Path         = $_.TaskPath
                State        = $info.State
                Author       = $_.Author
                Action       = ($_.Actions | ForEach-Object { $_.Execute }) -join ', '
                LastRunTime  = $info.LastRunTime
                NextRunTime  = $info.NextRunTime
            }
        }

        return $tasks
    }
    catch {
        Write-Warning "[-] Failed to enumerate scheduled tasks: $_"
        return @()
    }
}
