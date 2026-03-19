# stop_server.ps1 - Stop all services
$ErrorActionPreference = "Stop"

$REPO_DIR = Resolve-Path (Split-Path -Parent $MyInvocation.MyCommand.Path)
$LOG_DIR = "$REPO_DIR\logs"

Write-Host "Stopping Tang Political System services..."
Write-Host ""

# ==================== Stop Dashboard Server ====================

$dashboardProcess = Get-Process -Name "python" -ErrorAction SilentlyContinue | 
    Where-Object { $_.CommandLine -like "*dashboard\server.py*" }

if ($dashboardProcess) {
    Write-Host "Stopping dashboard server (PID: $($dashboardProcess.Id))..."
    Stop-Process -Id $dashboardProcess.Id -Force -ErrorAction SilentlyContinue
    Write-Host "Dashboard server stopped"
} else {
    Write-Host "Dashboard server not running"
}

# ==================== Stop Sync Loop ====================

$runLoopStopped = $false
$runLoopPidFile = "$LOG_DIR\run_loop.pid"

# Method 1: Stop by PID file
if (Test-Path $runLoopPidFile) {
    $runLoopPid = Get-Content $runLoopPidFile -ErrorAction SilentlyContinue
    if ($runLoopPid) {
        $proc = Get-Process -Id $runLoopPid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "Stopping data refresh loop (PID: $runLoopPid)..."
            Stop-Process -Id $runLoopPid -Force -ErrorAction SilentlyContinue
            Write-Host "Data refresh loop stopped"
            $runLoopStopped = $true
        }
        
        # Also stop child processes
        $pythonProcs = Get-Process -Name "python" -ErrorAction SilentlyContinue | 
            Where-Object { 
                $_.CommandLine -like "*sync_from_openclaw_runtime*" -or
                $_.CommandLine -like "*sync_agent_config*" -or
                $_.CommandLine -like "*apply_model_changes*" -or
                $_.CommandLine -like "*sync_officials_stats*" -or
                $_.CommandLine -like "*refresh_live_data*"
            }
        foreach ($proc in $pythonProcs) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
    }
    Remove-Item -Path $runLoopPidFile -Force -ErrorAction SilentlyContinue
}

# Method 2: Find and stop related processes
if (-not $runLoopStopped) {
    $syncProcs = Get-Process -Name "python" -ErrorAction SilentlyContinue | 
        Where-Object { 
            $_.CommandLine -like "*sync_from_openclaw_runtime*" -or
            $_.CommandLine -like "*sync_agent_config*" -or
            $_.CommandLine -like "*apply_model_changes*" -or
            $_.CommandLine -like "*sync_officials_stats*" -or
            $_.CommandLine -like "*refresh_live_data*"
        }
    
    if ($syncProcs) {
        Write-Host "Stopping data refresh processes..."
        foreach ($proc in $syncProcs) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
        Write-Host "Data refresh processes stopped"
        $runLoopStopped = $true
    }
}

if (-not $runLoopStopped) {
    Write-Host "Data refresh loop not running"
}

Write-Host ""
Write-Host "========================================"
Write-Host "All services stopped"
Write-Host "========================================"
Write-Host ""
Write-Host "Logs preserved in: $LOG_DIR"
Write-Host ""
Write-Host "To restart: .\start_server.ps1"
