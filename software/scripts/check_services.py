#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LumenIM 服务健康检查脚本
"""

import sys
import socket
import subprocess

def check_port(host, port, timeout=3):
    """检查端口是否开放"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except:
        return False

def main():
    host = "192.168.23.131"
    port = 22
    
    print("=" * 60)
    print(f"LumenIM Service Health Check - {host}")
    print("=" * 60)
    
    # Check SSH port
    print(f"\n[1] Checking SSH ({host}:{port})...")
    if check_port(host, port):
        print("    [OK] SSH port is open")
    else:
        print("    [FAIL] SSH port unreachable")
        return 1
    
    # Try SSH connection
    try:
        import paramiko
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        
        print("\n[2] SSH login...")
        client.connect(
            hostname=host,
            port=port,
            username="wenming429",
            password="wenming429",
            timeout=15,
            banner_timeout=15
        )
        print("    [OK] SSH login successful")
        
        # Check Docker containers
        print("\n[3] Docker containers:")
        stdin, stdout, stderr = client.exec_command("sudo docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>&1")
        output = stdout.read().decode('utf-8')
        print(output)
        
        # Check ports
        print("\n[4] Service ports:")
        stdin, stdout, stderr = client.exec_command("""
            for port in 3306 6379 9000 9090 9501 9502; do
                printf "Port %-5s: " $port
                if ss -tlnp 2>/dev/null | grep -q ":$port "; then
                    echo "[OK] Listening"
                else
                    echo "[FAIL] Not listening"
                fi
            done
        """)
        output = stdout.read().decode('utf-8')
        print(output)
        
        # Check MySQL
        print("\n[5] MySQL:")
        stdin, stdout, stderr = client.exec_command("sudo docker exec lumenim-mysql mysqladmin ping -h localhost -uroot -proot123456 2>/dev/null && echo 'MySQL OK' || echo 'MySQL FAILED'")
        output = stdout.read().decode('utf-8').strip()
        print(f"    {output}")
        
        # Check Redis
        print("\n[6] Redis:")
        stdin, stdout, stderr = client.exec_command("sudo docker exec lumenim-redis redis-cli ping 2>/dev/null")
        output = stdout.read().decode('utf-8').strip()
        if output == "PONG":
            print("    [OK] Redis responding")
        else:
            print(f"    [FAIL] Redis: {output}")
        
        # Check MinIO
        print("\n[7] MinIO:")
        stdin, stdout, stderr = client.exec_command("curl -s http://localhost:9000/minio/health/live 2>/dev/null || echo 'MinIO check'"
)
        output = stdout.read().decode('utf-8').strip()
        if output:
            print(f"    [OK] {output}")
        else:
            print("    [INFO] No response (may need health check)")
        
        # Check LumenIM HTTP
        print("\n[8] LumenIM HTTP (9501):")
        stdin, stdout, stderr = client.exec_command("curl -s -o /dev/null -w 'HTTP %{http_code}' http://localhost:9501/api/v1/health 2>/dev/null || echo 'Connection failed'")
        code = stdout.read().decode('utf-8').strip()
        print(f"    {code}")
        
        # Check logs for errors
        print("\n[9] Error logs (recent):")
        stdin, stdout, stderr = client.exec_command("sudo docker logs lumenim-http --tail 30 2>&1 | grep -iE 'error|panic|fatal|panic' | tail -10 || echo 'No errors found'")
        output = stdout.read().decode('utf-8').strip()
        if output and output != 'No errors found':
            print(f"    [WARN] Errors found:\n{output}")
        else:
            print("    [OK] No errors in logs")
        
        # System resources
        print("\n[10] System resources:")
        stdin, stdout, stderr = client.exec_command("df -h / | tail -1 && free -h | grep Mem")
        output = stdout.read().decode('utf-8')
        print(f"    {output}")
        
        # Docker stats
        print("\n[11] Container resource usage:")
        stdin, stdout, stderr = client.exec_command("sudo docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' 2>/dev/null || echo 'Docker stats unavailable'")
        output = stdout.read().decode('utf-8')
        print(output)
        
        client.close()
        
        print("\n" + "=" * 60)
        print("Health check completed")
        print("=" * 60)
        
    except ImportError:
        print("    [ERROR] paramiko not installed. Run: pip install paramiko")
        return 1
    except Exception as e:
        print(f"    [FAIL] Connection failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
