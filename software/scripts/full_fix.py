#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LumenIM 完整修复脚本
"""

import sys
import paramiko
import time

def ssh_exec(client, cmd, timeout=60):
    """执行SSH命令并返回输出"""
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    return stdout.read().decode('utf-8'), stderr.read().decode('utf-8')

def main():
    host = "192.168.23.131"
    
    print("=" * 60)
    print("LumenIM Full Fix Script")
    print("=" * 60)
    
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(host, 22, "wenming429", "wenming429", timeout=30, banner_timeout=30)
        print("[OK] SSH connected\n")
        
        # ========== 阶段1: 磁盘清理 ==========
        print("=" * 40)
        print("Stage 1: Disk Cleanup")
        print("=" * 40)
        
        # 检查大文件
        print("\n[1.1] Finding large files...")
        out, err = ssh_exec(client, "sudo find / -type f -size +50M -exec ls -lh {} \\; 2>/dev/null | sort -k5 -h | tail -20")
        print(out[:1500] if out else "None found")
        
        # 清理snap
        print("\n[1.2] Cleaning snap packages...")
        out, err = ssh_exec(client, "sudo snap list --all 2>/dev/null | awk '{print $1, $3}' | while read name ver; do sudo snap remove $name --revision=$ver 2>/dev/null; done || true")
        print("    Snap cleanup done")
        
        # 清理日志
        print("\n[1.3] Cleaning logs...")
        out, err = ssh_exec(client, "sudo find /var/log -type f -name '*.gz' -delete 2>/dev/null; sudo truncate -s 0 /var/log/*.log 2>/dev/null; sudo journalctl --vacuum-size=50M")
        print("    Logs cleaned")
        
        # 清理docker残留
        print("\n[1.4] Cleaning docker remnants...")
        out, err = ssh_exec(client, "sudo rm -rf /var/lib/docker/containers/* 2>/dev/null || true; sudo rm -rf /var/lib/docker/image/* 2>/dev/null || true")
        
        # 清理tmp
        print("\n[1.5] Cleaning temp files...")
        out, err = ssh_exec(client, "sudo rm -rf /tmp/* 2>/dev/null || true; sudo rm -rf /var/tmp/* 2>/dev/null || true")
        
        # 清理缓存
        print("\n[1.6] Cleaning apt cache...")
        out, err = ssh_exec(client, "sudo apt-get clean && sudo apt-get autoremove -y")
        
        # 清理旧内核
        print("\n[1.7] Cleaning old kernels...")
        out, err = ssh_exec(client, "sudo apt-get purge -y $(dpkg -l | grep '^ii' | grep -i 'linux-image-[0-9]' | awk '{print $2}' | grep -v $(uname -r) | head -3) 2>/dev/null || true")
        
        # 检查磁盘
        print("\n[1.8] Disk status after cleanup:")
        out, err = ssh_exec(client, "df -h /")
        print(out)
        
        # ========== 阶段2: 项目准备 ==========
        print("\n" + "=" * 40)
        print("Stage 2: Project Setup")
        print("=" * 40)
        
        # 检查项目目录
        print("\n[2.1] Checking project location...")
        out, err = ssh_exec(client, "ls -la /home/wenming429/")
        print(out)
        
        # 解压项目（如果存在zip）
        print("\n[2.2] Extracting project if needed...")
        out, err = ssh_exec(client, "cd /home/wenming429 && unzip -o lumenim-deploy.zip -d LumenIM 2>/dev/null || echo 'No zip file'")
        print(out[:500] if out else "")
        
        # 检查或创建LumenIM目录
        print("\n[2.3] Creating LumenIM directory...")
        out, err = ssh_exec(client, "mkdir -p /home/wenming429/LumenIM && ls -la /home/wenming429/LumenIM/ 2>/dev/null || echo 'Directory created'")
        print(out[:1000] if out else "")
        
        # ========== 阶段3: 传输配置文件 ==========
        print("\n" + "=" * 40)
        print("Stage 3: Upload Config Files")
        print("=" * 40)
        
        # 读取本地docker-compose文件
        print("\n[3.1] Reading local docker-compose config...")
        try:
            with open("d:/学习资料/AI_Projects/LumenIM/software/scripts/docker-compose-ubuntu.yaml", "r") as f:
                docker_compose = f.read()
            print("    Loaded docker-compose-ubuntu.yaml")
        except:
            print("    [WARN] Could not read local file, will use server config")
            docker_compose = None
        
        # 上传docker-compose
        if docker_compose:
            print("\n[3.2] Uploading docker-compose.yaml...")
            # 通过base64传输
            import base64
            content_b64 = base64.b64encode(docker_compose.encode()).decode()
            cmd = f'echo "{content_b64}" | base64 -d > /home/wenming429/LumenIM/docker-compose.yaml'
            ssh_exec(client, cmd)
            print("    Uploaded docker-compose.yaml")
        
        # 上传nginx.conf
        print("\n[3.3] Checking nginx config...")
        out, err = ssh_exec(client, "ls -la /home/wenming429/LumenIM/nginx.conf 2>/dev/null || echo 'nginx.conf not found'")
        print(f"    {out[:200] if out else ''}")
        
        # ========== 阶段4: 启动服务 ==========
        print("\n" + "=" * 40)
        print("Stage 4: Starting Services")
        print("=" * 40)
        
        # 检查docker
        print("\n[4.1] Docker version...")
        out, err = ssh_exec(client, "docker --version && docker compose version")
        print(f"    {out.strip()}")
        
        # 拉取镜像
        print("\n[4.2] Pulling images...")
        out, err = ssh_exec(client, "cd /home/wenming429/LumenIM && docker compose -f docker-compose-ubuntu.yaml pull 2>&1", timeout=300)
        print(out[:1000] if out else err[:500])
        
        # 启动服务
        print("\n[4.3] Starting containers...")
        out, err = ssh_exec(client, "cd /home/wenming429/LumenIM && docker compose -f docker-compose-ubuntu.yaml up -d 2>&1", timeout=120)
        print(out[:1000] if out else err[:500])
        
        # 等待服务启动
        print("\n[4.4] Waiting 60 seconds for services to initialize...")
        time.sleep(60)
        
        # ========== 阶段5: 验证服务 ==========
        print("\n" + "=" * 40)
        print("Stage 5: Service Verification")
        print("=" * 40)
        
        # 检查容器状态
        print("\n[5.1] Container status:")
        out, err = ssh_exec(client, "docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'")
        print(out)
        
        # 检查容器日志
        print("\n[5.2] Container logs (errors):")
        containers = ["lumenim-mysql", "lumenim-redis", "lumenim-minio", "lumenim-http", "lumenim-comet"]
        for c in containers:
            out, err = ssh_exec(client, f"docker logs {c} --tail 5 2>&1 | tail -3")
            if out:
                print(f"    {c}: {out.strip()[:100]}")
        
        # 健康检查
        print("\n[5.3] Health checks:")
        out, err = ssh_exec(client, "for port in 3306 6379 9000 9501 9502; do echo -n \"Port $port: \"; nc -z -w2 localhost $port && echo OK || echo FAIL; done")
        print(out)
        
        # 最终磁盘状态
        print("\n[5.4] Final disk status:")
        out, err = ssh_exec(client, "df -h /")
        print(out)
        
        client.close()
        
        print("\n" + "=" * 60)
        print("Fix script completed!")
        print("=" * 60)
        
    except Exception as e:
        print(f"[FAIL] Error: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
