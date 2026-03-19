#!/usr/bin/env python3
"""Test Gateway detection"""
import socket
import subprocess

def check_gateway():
    # 直接检查端口是否开放
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        result = sock.connect_ex(('127.0.0.1', 18789))
        sock.close()
        print(f'Socket result: {result}')
        if result == 0:
            print('Gateway is running (port check)')
            return True
    except Exception as e:
        print(f'Socket error: {e}')
    
    # 备用：使用 tasklist
    try:
        result = subprocess.run(
            ['tasklist', '/FI', 'IMAGENAME eq node.exe', '/FO', 'CSV'],
            capture_output=True, text=True, timeout=5
        )
        if 'node.exe' in result.stdout.lower():
            print('Gateway is running (tasklist check)')
            return True
    except Exception as e:
        print(f'Tasklist error: {e}')
    
    print('Gateway is NOT running')
    return False

if __name__ == '__main__':
    check_gateway()
