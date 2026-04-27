#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LumenIM 快速修复脚本
"""

import sys
import paramiko
import time

def main():
    host = "192.168.23.131"
    
    print("=" * 60)
    print("LumenIM Quick Fix")
    print("=" * 60)
    
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(host, 22, "wenming429", "wenming429", timeout=30)
        print("[OK] SSH connected\n")
        
        # Step 1: Restart Redis
        print("[1] Restarting Redis...")
        stdin, stdout, stderr = client.exec_command("sudo systemctl restart redis-server", timeout=10)
        stdout.channel.recv_exit_status()
        print("    Redis restarted")
        
        # Step 2: Check Redis
        print("\n[2] Redis status:")
        stdin, stdout, stderr = client.exec_command("redis-cli ping", timeout=5)
        print(f"    {stdout.read().decode().strip()}")
        
        # Step 3: Start comet service
        print("\n[3] Starting comet service...")
        stdin, stdout, stderr = client.exec_command("sudo systemctl start lumenim-comet", timeout=10)
        stdout.channel.recv_exit_status()
        time.sleep(3)
        
        # Step 4: Check ports
        print("\n[4] Service ports:")
        stdin, stdout, stderr = client.exec_command("ss -tlnp | grep -E '3306|6379|9000|9501|9502'", timeout=5)
        out = stdout.read().decode()
        print(out if out else "    No services")
        
        # Step 5: Check lumenim processes
        print("\n[5] LumenIM processes:")
        stdin, stdout, stderr = client.exec_command("ps aux | grep lumenim | grep -v grep", timeout=5)
        out = stdout.read().decode()
        print(out if out else "    No processes")
        
        # Step 6: Check systemd services
        print("\n[6] Systemd services:")
        stdin, stdout, stderr = client.exec_command("systemctl is-active lumenim-backend lumenim-comet 2>/dev/null", timeout=5)
        out = stdout.read().decode().strip()
        print(f"    lumenim-backend: {out.split()[0] if len(out.split()) > 0 else 'unknown'}")
        print(f"    lumenim-comet: {out.split()[1] if len(out.split()) > 1 else 'unknown'}")
        
        # Step 7: Health check
        print("\n[7] HTTP health check:")
        stdin, stdout, stderr = client.exec_command("curl -s http://localhost:9501/api/v1/health", timeout=5)
        out = stdout.read().decode().strip()
        print(f"    {out if out else 'No response'}")
        
        client.close()
        
        print("\n" + "=" * 60)
        print("Done!")
        print("=" * 60)
        
    except Exception as e:
        print(f"[FAIL] {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
