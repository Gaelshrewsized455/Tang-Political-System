# start_server.ps1 - Start dashboard server and sync loop (background)
$ErrorActionPreference = "Stop"

# 强制设置 UTF-8 代码页
$null = & "$env:SystemRoot\System32\chcp.com" 65001

$REPO_DIR = Resolve-Path (Split-Path -Parent $MyInvocation.MyCommand.Path)
$PYTHON = "C:\Users\HUAWEI\AppData\Local\Programs\Python\Python313\python.exe"
$LOG_DIR = "$REPO_DIR\logs"
$LOG_FILE = "$LOG_DIR\dashboard_server.log"

# Create log directory
if (-not (Test-Path $LOG_DIR)) {
    New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
}

# ==================== Start Dashboard Server ====================

# Check if already running
$existingDashboard = Get-Process -Name "python" -ErrorAction SilentlyContinue | 
    Where-Object { $_.CommandLine -like "*dashboard\server.py*" }

if ($existingDashboard) {
    Write-Host "Dashboard server already running (PID: $($existingDashboard.Id))"
    Write-Host "URL: http://127.0.0.1:7891"
} else {
    Write-Host "Starting dashboard server in background..."
    Write-Host "URL: http://127.0.0.1:7891"
    Write-Host "Log: $LOG_FILE"
    Write-Host ""

    # Start dashboard server in background
    $dashboardProcess = Start-Process -FilePath $PYTHON `
        -ArgumentList "$REPO_DIR\dashboard\server.py", "--port", "7891" `
        -WorkingDirectory $REPO_DIR `
        -WindowStyle Hidden `
        -RedirectStandardOutput $LOG_FILE `
        -RedirectStandardError "$LOG_DIR\dashboard_server.error.log" `
        -PassThru

    Write-Host "Dashboard server started (PID: $($dashboardProcess.Id))"
    
    # Wait and check
    Start-Sleep -Seconds 2
    if ($dashboardProcess.HasExited) {
        Write-Error "Dashboard server failed to start. Check: $LOG_DIR\dashboard_server.error.log"
        exit 1
    }
}

Write-Host ""

# ==================== Start Sync Loop ====================

$RUN_LOOP_LOG = "$LOG_DIR\run_loop.log"
$RUN_LOOP_PID = "$LOG_DIR\run_loop.pid"

# Check if already running
$runLoopRunning = $false
if (Test-Path $RUN_LOOP_PID) {
    $oldPid = Get-Content $RUN_LOOP_PID -ErrorAction SilentlyContinue
    if ($oldPid) {
        $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        if ($proc) {
            $runLoopRunning = $true
            Write-Host "Data refresh loop already running (PID: $oldPid)"
        }
    }
}

if (-not $runLoopRunning) {
    Write-Host "Starting data refresh loop in background..."
    Write-Host "Log: $RUN_LOOP_LOG"
    Write-Host "Interval: 15s"
    Write-Host ""

    # Start sync loop in background
    $runLoopProcess = Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-ExecutionPolicy", "Bypass", "-File", "$REPO_DIR\scripts\run_loop.ps1", "15" `
        -WorkingDirectory $REPO_DIR `
        -WindowStyle Hidden `
        -PassThru

    Write-Host "Data refresh loop started (PID: $($runLoopProcess.Id))"
    
    # Save PID
    $runLoopProcess.Id | Set-Content -Path $RUN_LOOP_PID -Force
    
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "========================================"
Write-Host "All services started successfully!"
Write-Host "========================================"
Write-Host ""
Write-Host "Dashboard URL: http://127.0.0.1:7891"
Write-Host ""
Write-Host "Commands:"
Write-Host "  View logs:        .\view_logs.ps1"
Write-Host "  View sync logs:   .\view_logs.ps1 -LogName runloop"
Write-Host "  Follow logs:      .\view_logs.ps1 -Follow"
Write-Host "  Stop all:         .\stop_server.ps1"
Write-Host ""
