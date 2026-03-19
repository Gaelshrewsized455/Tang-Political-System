#!/usr/bin/env python3
"""检查文件编码"""
import pathlib
import sys

def check_file_encoding(filepath):
    """检查文件编码并显示内容"""
    try:
        # 尝试 UTF-8
        content = pathlib.Path(filepath).read_text(encoding='utf-8')
        print(f"✅ {filepath}")
        print("=" * 50)
        print(content[:500])
        print("=" * 50)
        return True
    except Exception as e:
        print(f"❌ {filepath}: {e}")
        return False

if __name__ == '__main__':
    files = [
        'install.ps1',
        'scripts/run_loop.ps1',
        'scripts/sync_agent_config.py',
        'scripts/kanban_update.py',
    ]
    
    for f in files:
        check_file_encoding(f)
        print()
