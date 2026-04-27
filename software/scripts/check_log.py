import paramiko
import time

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)

print('=' * 60)
print('Check Startup Logs')
print('=' * 60)

# Check logs
print('\n[1] HTTP log:')
stdin, stdout, stderr = client.exec_command('cat /tmp/http.log 2>/dev/null | tail -50', timeout=5)
out = stdout.read().decode()
print(out if out else '   No log file')

print('\n[2] Comet log:')
stdin, stdout, stderr = client.exec_command('cat /tmp/comet.log 2>/dev/null | tail -50', timeout=5)
out = stdout.read().decode()
print(out if out else '   No log file')

# Try direct execution with output
print('\n[3] Try direct execution with output:')
stdin, stdout, stderr = client.exec_command('cd /var/www/lumenim/backend && ./lumenim http --config=/var/www/lumenim/backend/config.yaml 2>&1', timeout=10)
time.sleep(5)

# Check if it started
print('\n[4] Check if running:')
stdin, stdout, stderr = client.exec_command('ps aux | grep lumenim | grep -v grep', timeout=5)
print(stdout.read().decode())

stdin, stdout, stderr = client.exec_command('ss -tlnp | grep 9501', timeout=5)
out = stdout.read().decode()
print(f'Port 9501: {out.strip() if out else "Not listening"}')

# Kill and show output
stdin, stdout, stderr = client.exec_command('killall lumenim 2>/dev/null', timeout=5)

client.close()
print('\n' + '=' * 60)
