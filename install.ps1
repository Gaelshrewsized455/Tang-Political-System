# install.ps1
$ErrorActionPreference = "Stop"

# 设置 UTF-8 编码输出
chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$REPO_DIR = Resolve-Path (Split-Path -Parent $MyInvocation.MyCommand.Path)
$OC_HOME = "$env:USERPROFILE\.openclaw"
$OC_CFG = "$OC_HOME\openclaw.json"

function Log($msg) { Write-Host "OK: $msg" }
function Error($msg) { Write-Host "ERROR: $msg"; exit 1 }
function Info($msg) { Write-Host "INFO: $msg" }

Info "Checking dependencies..."
if (-not (Get-Command "openclaw" -ErrorAction SilentlyContinue)) {
    Error "openclaw CLI not found"
}
if (-not (Get-Command "python" -ErrorAction SilentlyContinue)) {
    if (-not (Get-Command "python3" -ErrorAction SilentlyContinue)) {
        Error "python not found"
    }
}
if (-not (Test-Path $OC_CFG)) {
    Error "openclaw.json not found"
}
Log "Dependencies OK"

Info "Configuring Emperor (main agent)..."

# 读取 openclaw.json
$openclawConfig = Get-Content -Path $OC_CFG -Raw | ConvertFrom-Json

# 找到 main agent 或第一个 agent
$mainAgent = $openclawConfig.agents | Where-Object { $_.id -eq "main" } | Select-Object -First 1
if (-not $mainAgent) {
    $mainAgent = $openclawConfig.agents | Select-Object -First 1
}

if ($mainAgent) {
    Info "Setting agent '$($mainAgent.id)' as Emperor..."
    
    # 添加 subagents 到 main agent（表示皇上可以调用这些 agent）
    $mainAgent | Add-Member -NotePropertyName "subagents" -NotePropertyValue @("zhongshu", "menxia", "shangshu", "hubu", "libu", "bingbu", "xingbu", "gongbu", "libu_hr", "zaochao") -Force
    
    # 保存回 openclaw.json
    $openclawConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $OC_CFG -Encoding UTF8
    Log "openclaw.json updated with subagents configuration"
    
    # 复制皇上 SOUL.md 到 main agent 的 workspace
    $emperorSoulSrc = "$REPO_DIR\agents\emperor\SOUL.md"
    $agentWorkspace = $mainAgent.workspace
    if (-not $agentWorkspace) {
        $agentWorkspace = "$OC_HOME\workspace"
    }
    $emperorSoulDst = "$agentWorkspace\SOUL.md"
    
    if (Test-Path $emperorSoulSrc) {
        $content = Get-Content -Path $emperorSoulSrc -Raw
        $content = $content.Replace("__REPO_DIR__", $REPO_DIR)
        Set-Content -Path $emperorSoulDst -Value $content -Encoding UTF8
        Log "Emperor SOUL.md copied to: $agentWorkspace"
    }
} else {
    Error "No agent found in openclaw.json"
}

Info "Creating workspaces for other agents..."
$AGENTS = @("zhongshu", "menxia", "shangshu", "hubu", "libu", "bingbu", "xingbu", "gongbu", "libu_hr", "zaochao")
foreach ($agent in $AGENTS) {
    $ws = "$OC_HOME\workspace-$agent"
    New-Item -ItemType Directory -Path "$ws\skills" -Force | Out-Null
    $soulSrc = "$REPO_DIR\agents\$agent\SOUL.md"
    $soulDst = "$ws\SOUL.md"
    if (Test-Path $soulSrc) {
        $content = Get-Content -Path $soulSrc -Raw
        $content = $content.Replace("__REPO_DIR__", $REPO_DIR)
        Set-Content -Path $soulDst -Value $content -Encoding UTF8
    }
}
Log "Workspaces created"

Info "Creating config files..."
# 创建项目端配置
New-Item -ItemType Directory -Path "$REPO_DIR\config" -Force | Out-Null
$pathsConfig = @{
    repo_dir = $REPO_DIR
    openclaw_home = $OC_HOME
    openclaw_workspace = "$OC_HOME\workspace"
    kanban_script = "$OC_HOME\workspace\scripts\kanban_update.py"
    tasks_file = "$REPO_DIR\data\tasks_source.json"
    refresh_script = "$REPO_DIR\scripts\refresh_live_data.py"
    install_date = Get-Date -Format "yyyy-MM-dd"
    version = "1.0.0"
} | ConvertTo-Json
Set-Content -Path "$REPO_DIR\config\paths.json" -Value $pathsConfig -Encoding UTF8

# 创建 workspace 端配置
New-Item -ItemType Directory -Path "$OC_HOME\workspace\config" -Force | Out-Null
$workspaceConfig = @{
    edict_repo = $REPO_DIR
    edict_config = "$REPO_DIR\config\paths.json"
    tasks_file = "$REPO_DIR\data\tasks_source.json"
    install_date = Get-Date -Format "yyyy-MM-dd"
    version = "1.0.0"
} | ConvertTo-Json
Set-Content -Path "$OC_HOME\workspace\config\config.json" -Value $workspaceConfig -Encoding UTF8
Log "Config files created"

Info "Copying kanban scripts to main workspace..."
$MAIN_WS = "$OC_HOME\workspace"
New-Item -ItemType Directory -Path "$MAIN_WS\scripts" -Force | Out-Null
Copy-Item -Path "$REPO_DIR\scripts\kanban_update.py" -Destination "$MAIN_WS\scripts\kanban_update.py" -Force
Copy-Item -Path "$REPO_DIR\scripts\file_lock.py" -Destination "$MAIN_WS\scripts\file_lock.py" -Force
Log "Kanban scripts copied"

Info "Registering agents..."
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item -Path $OC_CFG -Destination "$OC_CFG.bak.$timestamp" -Force
C:\Users\HUAWEI\AppData\Local\Programs\Python\Python313\python.exe "$REPO_DIR\scripts\register_agents.py"
Log "Agents registered"

Info "Initializing data..."
$DATA_DIR = "$REPO_DIR\data"
New-Item -ItemType Directory -Path $DATA_DIR -Force | Out-Null

Set-Content -Path "$DATA_DIR\live_status.json" -Value "{}" -Encoding UTF8
Set-Content -Path "$DATA_DIR\agent_config.json" -Value "{}" -Encoding UTF8
Set-Content -Path "$DATA_DIR\model_change_log.json" -Value "{}" -Encoding UTF8
Set-Content -Path "$DATA_DIR\pending_model_changes.json" -Value "[]" -Encoding UTF8

if (-not (Test-Path "$DATA_DIR\tasks_source.json")) {
    Copy-Item -Path "$REPO_DIR\data\tasks_source_template.json" -Destination "$DATA_DIR\tasks_source.json" -Force
}
Log "Data initialized"

Info "First sync..."
$env:REPO_DIR = $REPO_DIR
C:\Users\HUAWEI\AppData\Local\Programs\Python\Python313\python.exe "$REPO_DIR\scripts\sync_agent_config.py"
C:\Users\HUAWEI\AppData\Local\Programs\Python\Python313\python.exe "$REPO_DIR\scripts\refresh_live_data.py"
Log "Sync complete"

Info "Restarting gateway..."
openclaw gateway restart
Log "Done"

Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run: .\start_server.ps1       (启动看板服务器和同步循环)"
Write-Host "  2. Open: http://127.0.0.1:7891    (打开看板页面)"
Write-Host ""
Write-Host "其他命令:"
Write-Host "  .\stop_server.ps1                 (停止所有服务)"
Write-Host "  .\view_logs.ps1                   (查看运行日志)"
Write-Host "  .\view_logs.ps1 -Follow           (实时跟踪日志)"
