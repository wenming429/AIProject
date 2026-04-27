#!/usr/bin/env python3
import paramiko
import time

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)

print('=== Fixing Redis and Restarting Services ===')

# 1. Check Redis config
print('\n[1] Current Redis config:')
stdin, stdout, stderr = client.exec_command('sudo redis-cli CONFIG GET stop-writes-on-bgsave-error', timeout=10)
print(stdout.read().decode().strip())

stdin, stdout, stderr = client.exec_command('sudo redis-cli CONFIG GET dir', timeout=10)
print('dir:', stdout.read().decode().strip())

# 2. Fix Redis - disable stop-writes-on-bgsave-error
print('\n[2] Fixing Redis config...')
stdin, stdout, stderr = client.exec_command('sudo redis-cli CONFIG SET stop-writes-on-bgsave-error no', timeout=10)
print(stdout.read().decode().strip())

# 3. Verify
print('\n[3] Verify Redis:')
stdin, stdout, stderr = client.exec_command('sudo redis-cli ping', timeout=10)
print(stdout.read().decode().strip())

stdin, stdout, stderr = client.exec_command('sudo redis-cli SET test OK', timeout=10)
print(stdout.read().decode().strip())

# 4. Kill existing lumenim
print('\n[4] Killing existing lumenim...')
client.exec_command('sudo pkill -f lumenim', timeout=5)
time.sleep(2)

# 5. Check ports
print('\n[5] Current ports:')
stdin, stdout, stderr = client.exec_command('sudo ss -tlnp | grep -E "9501|9502"', timeout=10)
print(stdout.read().decode())

# 6. If not listening, start services
if '9502' not in stdout.read().decode():
    print('\n[6] Starting services...')
    stdin, stdout, stderr = client.exec_command('cd /var/www/lumenim/backend && sudo ./lumenim http > /tmp/http.log 2>&1 &', timeout=5)
    time.sleep(2)
    stdin, stdout, stderr = client.exec_command('cd /var/www/lumenim/backend && sudo ./lumenim comet > /tmp/comet.log 2>&1 &', timeout=5)
    time.sleep(3)

# 7. Final check
print('\n[7] Final port check:')
stdin, stdout, stderr = client.exec_command('sudo ss -tlnp | grep -E "9501|9502"', timeout=10)
result = stdout.read().decode()
print(result)

print('\n[8] Process check:')
stdin, stdout, stderr = client.exec_command('ps aux | grep lumenim | grep -v grep', timeout=10)
print(stdout.read().decode())

# 8. Check logs
if '9502' not in result:
    print('\n[9] Comet logs:')
    stdin, stdout, stderr = client.exec_command('tail -30 /tmp/comet.log', timeout=10)
    print(stdout.read().decode())

client.close()
print('\n=== Done ===')
