# 中文乱码问题解决方案

## 问题描述

在 Windows PowerShell 中查看文件时，中文显示为乱码（如"涓夌渷鍏"）。

**原因**：PowerShell 默认使用 GB2312 编码（代码页 936），而项目文件使用 UTF-8 编码。

## 解决方案

### 方案 1：使用支持 UTF-8 的编辑器查看（推荐）

使用以下编辑器打开文件，中文显示正常：
- VS Code
- Notepad++
- Sublime Text
- 任何现代代码编辑器

### 方案 2：在 PowerShell 中临时设置 UTF-8

```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
```

### 方案 3：修改 PowerShell 配置文件（永久）

已自动创建配置文件，下次打开 PowerShell 时自动生效：

```powershell
# 查看配置文件位置
$PROFILE

# 手动创建/编辑
notepad $PROFILE
```

添加以下内容：
```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
```

### 方案 4：修改系统区域设置

1. 打开"控制面板" → "区域" → "管理"
2. 点击"更改系统区域设置"
3. 勾选"Beta 版：使用 Unicode UTF-8 提供全球语言支持"
4. 重启电脑

## 验证文件编码正确

所有项目文件都使用 UTF-8 编码保存，中文内容完整。可以用 Python 验证：

```python
import pathlib
content = pathlib.Path('install.ps1').read_text(encoding='utf-8')
print(content[:500])  # 中文显示正常
```

## 脚本已做的处理

1. **install.ps1** - 开头自动设置 UTF-8 编码
2. **run_loop.ps1** - 开头自动设置 UTF-8 编码
3. **所有 Python 脚本** - 使用 `encoding='utf-8'` 读写文件
4. **PowerShell 配置文件** - 已创建，下次启动自动生效

## 总结

- ✅ 文件本身编码正确（UTF-8）
- ✅ 中文内容完整无误
- ✅ 脚本已自动处理编码设置
- ⚠️ PowerShell 终端显示需要设置 UTF-8 编码
