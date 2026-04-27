#!/usr/bin/env python3
import paramiko
import time

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)
print('=' * 60)
print('LumenIM Service Status Check (sudo)')
print('=' * 60)

# 1. Disk
print('\n[1] Disk Usage:')
stdin, stdout, stderr = client.exec_command('sudo df -h /', timeout=10)
print(stdout.read().decode())

# 2. All ports
print('[2] Service Ports (sudo):')
stdin, stdout, stderr = client.exec_command('sudo ss -tlnp | grep -E "3306|6379|9000|9501|9502|80 "', timeout=10)
out = stdout.read().decode()
print(out if out else '   No services')

# 3. Processes
print('[3] LumenIM Processes (sudo):')
stdin, stdout, stderr = client.exec_command('sudo ps aux | grep lumenim | grep -v grep', timeout=10)
out = stdout.read().decode()
print(out if out else '   None')

# 4. Systemd
print('[4] Systemd Services (sudo):')
stdin, stdout, stderr = client.exec_command('sudo systemctl is-active lumenim-backend lumenim-comet', timeout=10)
out = stdout.read().decode().strip()
lines = out.split('\n')
print(f'   backend: {lines[0] if lines else "unknown"}')
print(f'   comet: {lines[1] if len(lines) > 1 else "unknown"}')

# 5. Health
print('[5] HTTP Health Check:')
stdin, stdout, stderr = client.exec_command('curl -s http://localhost:9501/api/v1/health 2>/dev/null || curl -s http://localhost:9501/', timeout=10)
print(f'   {stdout.read().decode().strip()[:200]}')

# 6. Redis
print('[6] Redis (sudo):')
stdin, stdout, stderr = client.exec_command('sudo redis-cli ping', timeout=10)
print(f'   {stdout.read().decode().strip()}')

# 7. MySQL
print('[7] MySQL (sudo):')
stdin, stdout, stderr = client.exec_command('sudo mysqladmin ping -h localhost -uroot -proot123456 2>/dev/null && echo OK', timeout=10)
print(f'   {stdout.read().decode().strip()}')

# 8. MinIO
print('[8] MinIO (sudo):')
stdin, stdout, stderr = client.exec_command('curl -s http://localhost:9000/minio/health/live', timeout=10)
out = stdout.read().decode().strip()
print(f'   {out if out else "No response"}')

# 9. Nginx
print('[9] Nginx (sudo):')
stdin, stdout, stderr = client.exec_command('sudo systemctl is-active nginx', timeout=10)
print(f'   {stdout.read().decode().strip()}')

# 10. Docker
print('[10] Docker Containers (sudo):')
stdin, stdout, stderr = client.exec_command('sudo docker ps -a --format "table {{.Names}}\\t{{.Status}}"', timeout=10)
print(stdout.read().decode())

print('=' * 60)
client.close()
print('[Done]')
