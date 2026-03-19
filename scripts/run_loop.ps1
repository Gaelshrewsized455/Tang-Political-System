# run_loop.ps1 - 后台定时同步看板状态
$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPT_DIR = Resolve-Path $SCRIPT_DIR
$REPO_DIR = Resolve-Path "$SCRIPT_DIR\.."
$INTERVAL = if ($args[0]) { [int]$args[0] } else { 15 }

# 日志目录
$LOG_DIR = "$REPO_DIR\logs"
$LOG_FILE = "$LOG_DIR\run_loop.log"
$ERROR_LOG = "$LOG_DIR\run_loop.error.log"
$PIDFILE = "$LOG_DIR\run_loop.pid"

# 创建日志目录
if (-not (Test-Path $LOG_DIR)) {
    New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
}

# Single instance check
if (Test-Path $PIDFILE) {
    $OLD_PID = Get-Content $PIDFILE -ErrorAction SilentlyContinue
    if ($OLD_PID) {
        $proc = Get-Process -Id $OLD_PID -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "Already running (PID=$OLD_PID)"
            Write-Host "Log: $LOG_FILE"
            exit 1
        }
    }
    Remove-Item -Path $PIDFILE -Force -ErrorAction SilentlyContinue
}

# 启动后台进程
$action = {
    param($ScriptDir, $RepoDir, $Interval, $LogFile, $ErrorLog, $PidFile)
    
    $PID | Set-Content -Path $PidFile -Force
    
    function Log($msg) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp $msg" | Out-File -Append -FilePath $LogFile -Encoding UTF8
    }
    
    function Safe-Run($script) {
        $scriptPath = "$ScriptDir\$script"
        try {
            $proc = Start-Process -FilePath "python" -ArgumentList $scriptPath -PassThru -WindowStyle Hidden -RedirectStandardOutput "NUL" -RedirectStandardError $ErrorLog
            $proc.WaitForExit(30000)
            if (-not $proc.HasExited) {
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Log "Error running $script: $_"
        }
    }
    
    Log "Data refresh loop started (PID=$PID)"
    Log "Interval: ${Interval}s"
    Log "Scripts: $ScriptDir"
    
    while ($true) {
        try {
            Safe-Run "sync_from_openclaw_runtime.py"
            Safe-Run "sync_agent_config.py"
            Safe-Run "apply_model_changes.py"
            Safe-Run "sync_officials_stats.py"
            Safe-Run "refresh_live_data.py"
            Start-Sleep -Seconds $Interval
        } catch {
            Log "Loop error: $_"
            break
        }
    }
    
    Remove-Item -Path $PidFile -Force -ErrorAction SilentlyContinue
    Log "Data refresh loop stopped"
}

# 后台启动
$job = Start-Job -ScriptBlock $action -ArgumentList $SCRIPT_DIR, $REPO_DIR, $INTERVAL, $LOG_FILE, $ERROR_LOG, $PIDFILE

# 等待几秒检查是否成功启动
Start-Sleep -Seconds 2
if ($job.State -eq 'Failed') {
    Write-Error "Failed to start background process. Check error log: $ERROR_LOG"
    exit 1
}

# 获取实际进程ID
$actualPid = $job.Id

Write-Host "Data refresh loop started in background"
Write-Host "Job ID: $actualPid"
Write-Host "Log: $LOG_FILE"
Write-Host "Interval: ${INTERVAL}s"
Write-Host ""
Write-Host "常用命令："
Write-Host "  查看日志: Get-Content $LOG_FILE -Tail 20 -Wait"
Write-Host "  查看状态: Get-Job -Id $actualPid"
Write-Host "  停止同步: Stop-Job -Id $actualPid; Remove-Job -Id $actualPid"
Write-Host ""

# 分离作业，不阻塞当前窗口
$job | Out-Null
