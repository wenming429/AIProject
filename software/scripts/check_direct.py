#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
检查直接运行的服务状态
"""

import sys
import paramiko

def ssh_exec(client, cmd, timeout=30):
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    return stdout.read().decode('utf-8'), stderr.read().decode('utf-8')

def main():
    host = "192.168.23.131"
    
    print("=" * 60)
    print("Checking Direct Running Services")
    print("=" * 60)
    
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(host, 22, "wenming429", "wenming429", timeout=30)
        print("[OK] SSH connected\n")
        
        # 检查 lumenim 进程
        print("[1] LumenIM processes:")
        out, err = ssh_exec(client, "ps aux | grep -E 'lumenim|comet' | grep -v grep")
        print(out if out else "    No lumenim processes found")
        
        # 检查 lumenim 文件
        print("\n[2] LumenIM binary:")
        out, err = ssh_exec(client, "ls -la /home/wenming429/LumenIM/lumenim && file /home/wenming429/LumenIM/lumenim")
        print(out)
        
        # 检查 systemd 服务
        print("\n[3] Systemd services:")
        out, err = ssh_exec(client, "systemctl list-units --type=service | grep -i lumen")
        print(out if out else "    No lumenim systemd services")
        
        # 检查端口进程
        print("\n[4] Processes listening on ports:")
        out, err = ssh_exec(client, "ss -tlnp | grep -E '3306|6379|9000|9501|9502'")
        print(out)
        
        # 检查 MySQL
        print("\n[5] MySQL check:")
        out, err = ssh_exec(client, "mysqladmin ping -h localhost -uroot -proot123456 2>/dev/null && echo 'MySQL OK' || mysql -uroot -proot123456 -e 'SELECT 1' 2>&1")
        print(out.strip() if out else err.strip()[:200])
        
        # 检查 Redis
        print("\n[6] Redis check:")
        out, err = ssh_exec(client, "redis-cli ping")
        print(out.strip())
        
        # 检查 MinIO
        print("\n[7] MinIO check:")
        out, err = ssh_exec(client, "curl -s http://localhost:9000/minio/health/live")
        print(out if out else "No response")
        
        # 检查 LumenIM HTTP
        print("\n[8] LumenIM HTTP health:")
        out, err = ssh_exec(client, "curl -s http://localhost:9501/api/v1/health")
        print(out if out else "No response")
        
        # 启动 WebSocket 服务
        print("\n[9] Starting WebSocket service (comet)...")
        out, err = ssh_exec(client, "cd /home/wenming429/LumenIM && nohup ./lumenim comet > /tmp/comet.log 2>&1 &")
        print(f"    Command executed: {out if out else 'OK'}")
        
        # 等待启动
        import time
        time.sleep(5)
        
        # 检查 WebSocket 端口
        print("\n[10] Checking WebSocket port (9502):")
        out, err = ssh_exec(client, "ss -tlnp | grep 9502")
        print(out if out else "    Port 9502 still not listening")
        
        # 检查日志
        print("\n[11] Comet log:")
        out, err = ssh_exec(client, "tail -20 /tmp/comet.log")
        print(out[:500] if out else "No log file")
        
        # 最终端口检查
        print("\n[12] Final port status:")
        out, err = ssh_exec(client, "ss -tlnp | grep -E '3306|6379|9000|9501|9502'")
        print(out)
        
        client.close()
        
        print("\n" + "=" * 60)
        print("Check completed")
        print("=" * 60)
        
    except Exception as e:
        print(f"[FAIL] Error: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
