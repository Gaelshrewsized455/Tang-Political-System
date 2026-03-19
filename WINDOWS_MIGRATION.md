# 三省六部 Edict - Windows 迁移说明

## 修改概述

本项目已从 Linux/macOS 专用改为 Windows 专用。

## 新增文件

1. **install.ps1** - Windows PowerShell 安装脚本（替代 install.sh）
2. **scripts/run_loop.ps1** - Windows 数据刷新循环脚本（替代 run_loop.sh）
3. **scripts/register_agents.py** - Agent 注册脚本
4. **data/tasks_source_template.json** - 初始任务模板

## 修改的文件

### 1. scripts/file_lock.py
- 将 Linux `fcntl` 文件锁替换为 Windows 兼容实现
- 使用 `portalocker` 库（如果可用）或线程锁作为备用

### 2. scripts/kanban_update.py
- 更新文件路径处理以支持 Windows
- 将 `python3` 命令改为 `python`

### 3. scripts/utils.py
- 添加 `encoding='utf-8'` 参数到文件读取操作

### 4. scripts/sync_agent_config.py
- 添加 `encoding='utf-8'` 到所有文件读取操作

## 安装步骤

1. 确保已安装 Python 3.9+ 和 OpenClaw
2. 在 PowerShell 中运行：
   ```powershell
   .\install.ps1
   ```

3. 启动数据刷新循环：
   ```powershell
   .\scripts\run_loop.ps1
   ```

4. 启动看板服务器：
   ```powershell
   python dashboard\server.py
   ```

5. 打开浏览器访问：http://127.0.0.1:7891

## 注意事项

1. 所有脚本现在使用 `python` 命令而不是 `python3`
2. 路径使用 Windows 格式（反斜杠）
3. 日志文件存储在 `%TEMP%` 目录
4. 文件锁使用 Windows 兼容实现

## 回滚

如果需要恢复 Linux/macOS 版本：
```bash
git checkout -- install.sh scripts/run_loop.sh scripts/file_lock.py
```
