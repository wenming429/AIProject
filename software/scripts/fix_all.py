#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LumenIM 完整服务修复脚本
"""

import sys
import paramiko
import time

def ssh_exec(client, cmd, timeout=30):
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    return stdout.read().decode('utf-8'), stderr.read().decode('utf-8')

def main():
    host = "192.168.23.131"
    
    print("=" * 60)
    print("LumenIM Complete Service Fix")
    print("=" * 60)
    
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(host, 22, "wenming429", "wenming429", timeout=30)
        print("[OK] SSH connected\n")
        
        # ========== 修复 Redis ==========
        print("=" * 40)
        print("Step 1: Fix Redis")
        print("=" * 40)
        
        # 检查 Redis 数据目录
        print("\n[1.1] Checking Redis data directory...")
        out, err = ssh_exec(client, "ls -la /var/lib/redis/ && df -h /var/lib/redis/")
        print(out)
        
        # 修复 Redis 权限
        print("\n[1.2] Fixing Redis permissions...")
        out, err = ssh_exec(client, "sudo chown redis:redis /var/lib/redis && sudo chmod 770 /var/lib/redis")
        print("    Permissions fixed")
        
        # 重启 Redis
        print("\n[1.3] Restarting Redis...")
        out, err = ssh_exec(client, "sudo systemctl restart redis-server && sleep 2 && sudo systemctl status redis-server | head -10")
        print(out[:500] if out else "Restarted")
        
        # 检查 Redis
        print("\n[1.4] Redis check:")
        out, err = ssh_exec(client, "redis-cli ping")
        print(f"    {out.strip()}")
        
        # ========== 修复/启动 MinIO ==========
        print("\n" + "=" * 40)
        print("Step 2: Fix MinIO")
        print("=" * 40)
        
        # 检查 MinIO 状态
        print("\n[2.1] Checking MinIO service...")
        out, err = ssh_exec(client, "sudo systemctl status minio | head -15")
        print(out[:800] if out else "MinIO not found as systemd service")
        
        # 检查 MinIO 进程
        print("\n[2.2] MinIO process:")
        out, err = ssh_exec(client, "ps aux | grep -E 'minio|mc' | grep -v grep")
        print(out if out else "    No MinIO process")
        
        # ========== 启动 LumenIM Comet ==========
        print("\n" + "=" * 40)
        print("Step 3: Start LumenIM Comet (WebSocket)")
        print("=" * 40)
        
        # 检查 lumenim 二进制位置
        print("\n[3.1] Finding lumenim binary...")
        out, err = ssh_exec(client, "ls -la /var/www/lumenim/backend/lumenim")
        print(out)
        
        # 使用 systemd 启动 comet 服务
        print("\n[3.2] Starting comet service via systemd...")
        out, err = ssh_exec(client, "sudo systemctl start lumenim-comet && sleep 3 && sudo systemctl status lumenim-comet | head -15")
        print(out[:800] if out else err[:500])
        
        # 检查端口
        print("\n[3.3] Checking WebSocket port (9502):")
        out, err = ssh_exec(client, "ss -tlnp | grep 9502")
        print(out if out else "    Port 9502 not listening")
        
        # 如果 systemd 失败，尝试直接启动
        if not out or ':9502' not in out:
            print("\n[3.4] Trying direct start...")
            # 先停止 systemd 版本
            ssh_exec(client, "sudo systemctl stop lumenim-comet 2>/dev/null")
            # 使用正确路径启动
            out, err = ssh_exec(client, "cd /var/www/lumenim/backend && sudo nohup ./lumenim comet > /tmp/comet.log 2>&1 &")
            print("    Started directly")
            time.sleep(5)
            
            # 检查端口
            out, err = ssh_exec(client, "ss -tlnp | grep 9502")
            print(f"    {out if out else 'Still not listening'}")
            
            # 检查日志
            print("\n[3.5] Comet log:")
            out, err = ssh_exec(client, "tail -30 /tmp/comet.log")
            print(out[:500] if out else "No log")
        
        # ========== 最终检查 ==========
        print("\n" + "=" * 40)
        print("Step 4: Final Status Check")
        print("=" * 40)
        
        # 所有端口
        print("\n[4.1] All service ports:")
        out, err = ssh_exec(client, "ss -tlnp | grep -E '3306|6379|9000|9501|9502'")
        print(out if out else "    No services listening")
        
        # 健康检查
        print("\n[4.2] Health checks:")
        
        out, err = ssh_exec(client, "curl -s http://localhost:9501/api/v1/health 2>/dev/null || echo 'HTTP: FAIL'")
        print(f"    HTTP (9501): {out.strip()}")
        
        # 检查 lumenim 进程
        print("\n[4.3] LumenIM processes:")
        out, err = ssh_exec(client, "ps aux | grep lumenim | grep -v grep")
        print(out if out else "    No lumenim processes")
        
        # systemd 服务状态
        print("\n[4.4] Systemd services:")
        out, err = ssh_exec(client, "systemctl status lumenim-backend lumenim-comet --no-pager 2>&1 | grep -E 'lumenim|Active:'")
        print(out[:500] if out else "    No services")
        
        client.close()
        
        print("\n" + "=" * 60)
        print("Fix completed!")
        print("=" * 60)
        
    except Exception as e:
        print(f"[FAIL] Error: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
