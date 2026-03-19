# view_logs.ps1 - View logs
param(
    [string]$LogName = "dashboard",
    [int]$Tail = 50,
    [switch]$Follow
)

$REPO_DIR = Resolve-Path (Split-Path -Parent $MyInvocation.MyCommand.Path)
$LOG_DIR = "$REPO_DIR\logs"

if (-not (Test-Path $LOG_DIR)) {
    Write-Host "Log directory not found: $LOG_DIR"
    exit 1
}

$logFiles = @{
    "dashboard" = "$LOG_DIR\dashboard_server.log"
    "dashboard-error" = "$LOG_DIR\dashboard_server.error.log"
    "runloop" = "$LOG_DIR\run_loop.log"
    "runloop-error" = "$LOG_DIR\run_loop.error.log"
    "all" = $null
}

if (-not $logFiles.ContainsKey($LogName)) {
    Write-Host "Unknown log name: $LogName"
    Write-Host "Available: $($logFiles.Keys -join ', ')"
    exit 1
}

$logFile = $logFiles[$LogName]

if ($LogName -eq "all") {
    Write-Host "=== All Logs ==="
    Write-Host ""
    Get-ChildItem -Path $LOG_DIR -Filter "*.log" | ForEach-Object {
        Write-Host "--- $($_.Name) ---"
        Get-Content $_.FullName -Tail $Tail
        Write-Host ""
    }
} else {
    if (-not (Test-Path $logFile)) {
        Write-Host "Log file not found: $logFile"
        exit 1
    }
    
    Write-Host "=== $LogName Log ==="
    Write-Host "File: $logFile"
    Write-Host ""
    
    if ($Follow) {
        Get-Content $logFile -Tail $Tail -Wait
    } else {
        Get-Content $logFile -Tail $Tail
    }
}
