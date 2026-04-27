#!/usr/bin/env python3
import paramiko
import time
import sys

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)

print('=== Fixing WebSocket Service ===')

# Check current state
print('\n[1] Current port status:')
stdin, stdout, stderr = client.exec_command('sudo ss -tlnp | grep -E "9501|9502"', timeout=10)
print(stdout.read().decode())

# Stop any existing lumenim
print('\n[2] Stopping existing processes...')
client.exec_command('sudo pkill -f lumenim', timeout=5)
time.sleep(1)

# Start HTTP
print('\n[3] Starting HTTP service...')
stdin, stdout, stderr = client.exec_command('cd /var/www/lumenim/backend && sudo nohup ./lumenim http > /tmp/lumenim_http.log 2>&1 &', timeout=5)
time.sleep(2)

# Start Comet (WebSocket)
print('\n[4] Starting Comet (WebSocket)...')
stdin, stdout, stderr = client.exec_command('cd /var/www/lumenim/backend && sudo nohup ./lumenim comet > /tmp/lumenim_comet.log 2>&1 &', timeout=5)
time.sleep(3)

# Check result
print('\n[5] Checking ports:')
stdin, stdout, stderr = client.exec_command('sudo ss -tlnp | grep -E "9501|9502"', timeout=10)
result = stdout.read().decode()
print(result)

if '9502' in result:
    print('\n[OK] WebSocket (9502) is now listening!')
else:
    print('\n[FAIL] Still not working, checking logs...')
    stdin, stdout, stderr = client.exec_command('tail -20 /tmp/lumenim_comet.log', timeout=10)
    print(stdout.read().decode())

# Check comet process
print('\n[6] Checking processes:')
stdin, stdout, stderr = client.exec_command('ps aux | grep lumenim | grep -v grep', timeout=10)
print(stdout.read().decode())

client.close()
print('\n=== Done ===')
