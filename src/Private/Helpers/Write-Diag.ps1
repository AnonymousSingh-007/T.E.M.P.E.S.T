function Write-Diag {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $ts = (Get-Date).ToString("HH:mm:ss.fff")
    Write-Host "[$ts][$Level] $Message" -ForegroundColor DarkGray
}
