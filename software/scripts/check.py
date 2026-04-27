import paramiko
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)
print('=' * 60)
print('LumenIM Service Check')
print('=' * 60)

print('\n[1] Disk Usage:')
stdin, stdout, stderr = client.exec_command('df -h /', timeout=5)
print(stdout.read().decode())

print('[2] Service Ports:')
stdin, stdout, stderr = client.exec_command('ss -tlnp | grep -E "3306|6379|9000|9501|9502"', timeout=5)
out = stdout.read().decode()
print(out if out else '   No services')

print('[3] LumenIM Processes:')
stdin, stdout, stderr = client.exec_command('ps aux | grep lumenim | grep -v grep', timeout=5)
out = stdout.read().decode()
print(out if out else '   None')

print('[4] Systemd Services:')
stdin, stdout, stderr = client.exec_command('systemctl is-active lumenim-backend lumenim-comet', timeout=5)
out = stdout.read().decode().strip()
parts = out.split()
print(f'   backend: {parts[0]}')
print(f'   comet: {parts[1] if len(parts) > 1 else "unknown"}')

print('[5] HTTP Health:')
stdin, stdout, stderr = client.exec_command('curl -s http://localhost:9501/api/v1/health', timeout=5)
print(f'   {stdout.read().decode().strip()}')

print('[6] Redis:')
stdin, stdout, stderr = client.exec_command('redis-cli ping', timeout=5)
print(f'   {stdout.read().decode().strip()}')

print('[7] MySQL:')
stdin, stdout, stderr = client.exec_command('mysqladmin ping -h localhost -uroot -proot123456 2>/dev/null && echo OK', timeout=5)
print(f'   {stdout.read().decode().strip()}')

print('=' * 60)
client.close()
print('[Done]')
