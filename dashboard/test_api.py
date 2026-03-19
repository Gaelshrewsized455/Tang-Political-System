#!/usr/bin/env python3
"""Test API directly"""
import sys
import pathlib

# Add scripts to path
scripts_dir = str(pathlib.Path(__file__).parent.parent / 'scripts')
sys.path.insert(0, scripts_dir)

from server import _check_gateway_alive, _check_gateway_probe, get_agents_status

print("Testing Gateway detection...")
print(f"_check_gateway_alive: {_check_gateway_alive()}")
print(f"_check_gateway_probe: {_check_gateway_probe()}")

status = get_agents_status()
print(f"\nGateway status from API: {status.get('gateway', {})}")
