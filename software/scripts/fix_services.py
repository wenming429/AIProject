#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LumenIM 服务修复脚本
"""

import sys
import paramiko

def main():
    host = "192.168.23.131"
    
    print("=" * 60)
    print("LumenIM Service Fix Script")
    print("=" * 60)
    
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(
            hostname=host,
            port=22,
            username="wenming429",
            password="wenming429",
            timeout=30,
            banner_timeout=30
        )
        print("[OK] SSH connected")
        
        # Step 1: Check disk usage
        print("\n[1] Checking disk usage...")
        stdin, stdout, stderr = client.exec_command("df -h")
        output = stdout.read().decode('utf-8')
        print(output)
        
        # Step 2: Clean Docker resources
        print("\n[2] Cleaning Docker resources...")
        commands = [
            "sudo docker system prune -af --volumes",
            "sudo docker volume prune -f",
            "sudo rm -rf /var/lib/docker/tmp/* 2>/dev/null || true",
            "sudo journalctl --vacuum-time=3d",
            "sudo apt-get clean -y"
        ]
        for cmd in commands:
            print(f"    Running: {cmd[:50]}...")
            stdin, stdout, stderr = client.exec_command(cmd)
            stdout.channel.recv_exit_status()
            output = stdout.read().decode('utf-8').strip()
            if output:
                print(f"        {output[:100]}")
        
        # Step 3: Check Docker data size
        print("\n[3] Docker data size:")
        stdin, stdout, stderr = client.exec_command("sudo du -sh /var/lib/docker 2>/dev/null || echo 'N/A'")
        output = stdout.read().decode('utf-8').strip()
        print(f"    {output}")
        
        # Step 4: Stop all containers
        print("\n[4] Stopping all containers...")
        stdin, stdout, stderr = client.exec_command("sudo docker stop $(sudo docker ps -aq) 2>/dev/null || echo 'No containers to stop'")
        stdout.channel.recv_exit_status()
        print("    Done")
        
        # Step 5: Remove stopped containers
        print("\n[5] Removing stopped containers...")
        stdin, stdout, stderr = client.exec_command("sudo docker container prune -f")
        stdout.channel.recv_exit_status()
        print("    Done")
        
        # Step 6: Check disk again
        print("\n[6] Disk usage after cleanup:")
        stdin, stdout, stderr = client.exec_command("df -h /")
        output = stdout.read().decode('utf-8')
        print(output)
        
        # Step 7: Start services
        print("\n[7] Starting services...")
        
        # Check docker-compose file
        stdin, stdout, stderr = client.exec_command("ls -la /home/wenming429/LumenIM/docker-compose.yaml 2>/dev/null || ls -la ~/LumenIM/docker-compose.yaml 2>/dev/null || echo 'docker-compose.yaml not found'")
        output = stdout.read().decode('utf-8').strip()
        print(f"    {output}")
        
        # Try to find project directory
        stdin, stdout, stderr = client.exec_command("find /home -name 'docker-compose*.yaml' -type f 2>/dev/null | head -5")
        output = stdout.read().decode('utf-8').strip()
        print(f"    Project files: {output or 'Not found'}")
        
        # Check if lumenim directory exists
        stdin, stdout, stderr = client.exec_command("ls -la /home/wenming429/ 2>/dev/null | grep -i lumen")
        output = stdout.read().decode('utf-8').strip()
        print(f"    LumenIM dir: {output or 'Not found'}")
        
        # Step 8: Pull latest images
        print("\n[8] Pulling latest images...")
        stdin, stdout, stderr = client.exec_command("sudo docker-compose -f /home/wenming429/LumenIM/docker-compose-ubuntu.yaml pull 2>&1")
        output = stdout.read().decode('utf-8')
        print(output[:500] if len(output) > 500 else output)
        
        # Step 9: Start containers
        print("\n[9] Starting containers...")
        stdin, stdout, stderr = client.exec_command("cd /home/wenming429/LumenIM && sudo docker-compose -f docker-compose-ubuntu.yaml up -d 2>&1")
        output = stdout.read().decode('utf-8')
        print(output[:800] if len(output) > 800 else output)
        
        # Wait and check
        print("\n[10] Waiting 30 seconds for services to start...")
        import time
        time.sleep(30)
        
        # Check status
        print("\n[11] Container status after start:")
        stdin, stdout, stderr = client.exec_command("sudo docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'")
        output = stdout.read().decode('utf-8')
        print(output)
        
        # Check health endpoints
        print("\n[12] Health checks:")
        
        # Check MySQL
        stdin, stdout, stderr = client.exec_command("sudo docker exec lumenim-mysql mysqladmin ping -h localhost -uroot -plumenim123 2>/dev/null && echo 'MySQL: OK' || echo 'MySQL: FAIL'")
        print(f"    {stdout.read().decode('utf-8').strip()}")
        
        # Check Redis
        stdin, stdout, stderr = client.exec_command("sudo docker exec lumenim-redis redis-cli ping 2>/dev/null")
        output = stdout.read().decode('utf-8').strip()
        print(f"    Redis: {output or 'NO RESPONSE'}")
        
        # Check HTTP
        stdin, stdout, stderr = client.exec_command("curl -s -o /dev/null -w 'HTTP %{http_code}' http://localhost:9501/api/v1/health 2>/dev/null || echo 'HTTP: FAIL'")
        print(f"    {stdout.read().decode('utf-8').strip()}")
        
        # Final disk check
        print("\n[13] Final disk check:")
        stdin, stdout, stderr = client.exec_command("df -h /")
        output = stdout.read().decode('utf-8')
        print(output)
        
        client.close()
        
        print("\n" + "=" * 60)
        print("Fix completed. Check status above.")
        print("=" * 60)
        
    except Exception as e:
        print(f"[FAIL] Error: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
