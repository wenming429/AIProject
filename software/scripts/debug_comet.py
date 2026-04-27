import paramiko
import time

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)

print('=' * 60)
print('WebSocket (9502) Debug')
print('=' * 60)

# 1. Check systemd service status
print('\n[1] Systemd service status:')
stdin, stdout, stderr = client.exec_command('systemctl status lumenim-comet --no-pager -l', timeout=10)
print(stdout.read().decode()[:1500])

# 2. Check service file
print('\n[2] Service file:')
stdin, stdout, stderr = client.exec_command('cat /etc/systemd/system/lumenim-comet.service', timeout=5)
print(stdout.read().decode())

# 3. Check logs
print('\n[3] Recent logs:')
stdin, stdout, stderr = client.exec_command('journalctl -u lumenim-comet -n 30 --no-pager', timeout=10)
out = stdout.read().decode()
print(out[:1000] if out else 'No logs')

# 4. Try manual start
print('\n[4] Try manual start:')
stdin, stdout, stderr = client.exec_command('cd /var/www/lumenim/backend && sudo ./lumenim comet 2>&1 &', timeout=5)
time.sleep(5)

print('\n[5] Check after manual start:')
stdin, stdout, stderr = client.exec_command('ss -tlnp | grep 9502', timeout=5)
out = stdout.read().decode()
print(out if out else '   Port 9502 not listening')

print('\n[6] Process check:')
stdin, stdout, stderr = client.exec_command('ps aux | grep lumenim | grep -v grep', timeout=5)
print(stdout.read().decode())

# 5. Check config
print('\n[7] Config file:')
stdin, stdout, stderr = client.exec_command('ls -la /var/www/lumenim/backend/config.yaml', timeout=5)
print(stdout.read().decode())

client.close()
print('\n' + '=' * 60)
