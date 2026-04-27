#!/usr/bin/env python3
"""
服务器健康检查脚本
检查 LumenIM 项目所需的服务端口和运行状态
"""

import subprocess
import socket
import sys
from typing import Tuple, List, Dict

# 服务器配置
SERVER = "192.168.23.131"
USERNAME = "wenming429"
PASSWORD = "wenming429"

# 需要检查的端口和服务
SERVICES = [
    {"port": 3306, "name": "MySQL", "check": "mysqladmin ping -h localhost -uroot -plumenim123 2>/dev/null || echo 'MySQL not accessible with lumenim credentials'"},
    {"port": 6379, "name": "Redis", "check": "redis-cli ping"},
    {"port": 9000, "name": "MinIO API", "check": "curl -s http://localhost:9000/minio/health/live || echo 'FAILED'"},
    {"port": 9090, "name": "MinIO Console", "check": "curl -s http://localhost:9090/minio/health/live || echo 'FAILED'"},
    {"port": 9501, "name": "LumenIM HTTP", "check": "curl -s http://localhost:9501/api/v1/health || echo 'FAILED'"},
    {"port": 9502, "name": "LumenIM WebSocket", "check": "netstat -tlnp 2>/dev/null | grep 9502 || ss -tlnp | grep 9502 || echo 'Not listening'"},
    {"port": 80, "name": "Nginx HTTP", "check": "systemctl is-active nginx"},
    {"port": 443, "name": "Nginx HTTPS", "check": "systemctl is-active nginx"},
]

def check_port(host: str, port: int) -> Tuple[bool, str]:
    """检查端口是否开放"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((host, port))
        sock.close()
        return (result == 0, "✓ Open" if result == 0 else "✗ Closed")
    except Exception as e:
        return (False, f"✗ Error: {str(e)}")

def run_ssh_command(cmd: str) -> Tuple[bool, str]:
    """使用 SSH 远程执行命令（通过 cmd.exe /c 调用 OpenSSH）"""
    try:
        # 使用 SSH 命令远程执行
        full_cmd = f'sshpass -p "{PASSWORD}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 {USERNAME}@{SERVER} "{cmd}"'
        result = subprocess.run(
            full_cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=30
        )
        if result.returncode == 0:
            return (True, result.stdout.strip())
        else:
            return (False, result.stderr.strip() or result.stdout.strip())
    except subprocess.TimeoutExpired:
        return (False, "✗ Timeout")
    except Exception as e:
        return (False, f"✗ Error: {str(e)}")

def check_service_via_ssh(port: int, name: str, check_cmd: str) -> Dict:
    """通过 SSH 检查服务"""
    # 先检查端口
    port_ok, port_msg = check_port(SERVER, port)
    
    # 获取服务进程信息
    proc_cmd = f"netstat -tlnp 2>/dev/null | grep ':{port}' || ss -tlnp | grep ':{port}' || echo 'No process found'"
    proc_ok, proc_info = run_ssh_command(proc_cmd)
    
    # 执行服务特定检查
    service_ok, service_info = run_ssh_command(check_cmd)
    
    return {
        "port": port,
        "name": name,
        "port_open": port_ok,
        "process": proc_info if proc_ok else proc_info,
        "service_check": service_info if service_ok else service_info,
        "status": "✓ OK" if port_ok and service_ok else "✗ ISSUE"
    }

def main():
    print("=" * 60)
    print(f"服务器健康检查: {SERVER}")
    print("=" * 60)
    
    # 测试 SSH 连接
    print("\n[1] 测试 SSH 连接...")
    ok, result = run_ssh_command("echo 'SSH OK' && hostname && uptime")
    if ok:
        print(f"    ✓ SSH 连接成功")
        print(f"    {result.split(chr(10))[0]}")
    else:
        print(f"    ✗ SSH 连接失败: {result}")
        sys.exit(1)
    
    # 检查 Docker 容器
    print("\n[2] 检查 Docker 容器状态...")
    ok, result = run_ssh_command("docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || echo 'Docker not available'")
    if ok:
        print(result)
    else:
        print(f"    ✗ {result}")
    
    # 检查所有服务端口
    print("\n[3] 检查服务端口...")
    print("-" * 60)
    print(f"{'端口':<8} {'服务':<20} {'端口状态':<10} {'服务检查'}")
    print("-" * 60)
    
    issues = []
    for svc in SERVICES:
        result = check_service_via_ssh(svc["port"], svc["name"], svc["check"])
        status_icon = "✓" if result["port_open"] else "✗"
        print(f"{result['port']:<8} {result['name']:<20} {status_icon:<10} {result['service_check'][:40]}")
        if not result["port_open"]:
            issues.append(f"{result['name']} (端口 {result['port']}) 未开放")
    
    # 检查系统资源
    print("\n[4] 检查系统资源...")
    ok, result = run_ssh_command("df -h / | tail -1 && free -h | grep Mem")
    if ok:
        print(f"    {result}")
    
    # 检查磁盘空间
    print("\n[5] 检查 Docker 资源...")
    ok, result = run_ssh_command("docker system df 2>/dev/null || echo 'Docker stats not available'")
    if ok:
        print(result)
    
    # 总结
    print("\n" + "=" * 60)
    if issues:
        print("⚠️  发现问题:")
        for issue in issues:
            print(f"    - {issue}")
    else:
        print("✓ 所有服务端口正常")
    print("=" * 60)
    
    return len(issues)

if __name__ == "__main__":
    sys.exit(main())
