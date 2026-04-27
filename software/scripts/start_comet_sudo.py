#!/usr/bin/env python3
import paramiko
import time

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)

print('=' * 60)
print('Starting LumenIM Comet Service')
print('=' * 60)

# 1. Start comet via systemd
print('\n[1] Starting lumenim-comet via systemd...')
stdin, stdout, stderr = client.exec_command('sudo systemctl start lumenim-comet', timeout=10)
stdout.channel.recv_exit_status()
time.sleep(2)

# 2. Check status
print('[2] Checking status...')
stdin, stdout, stderr = client.exec_command('sudo systemctl status lumenim-comet --no-pager', timeout=10)
print(stdout.read().decode())

# 3. Check port
print('[3] Checking port 9502...')
stdin, stdout, stderr = client.exec_command('sudo ss -tlnp | grep 9502', timeout=10)
out = stdout.read().decode().strip()
if out:
    print(f'   OK: {out}')
else:
    print('   Not listening, trying manual start...')
    
    # 4. Try manual start
    stdin, stdout, stderr = client.exec_command('sudo pkill lumenim 2>/dev/null; sleep 1', timeout=5)
    stdin, stdout, stderr = client.exec_command('cd /var/www/lumenim/backend && sudo ./lumenim comet &', timeout=5)
    time.sleep(3)
    
    stdin, stdout, stderr = client.exec_command('sudo ss -tlnp | grep 9502', timeout=10)
    out = stdout.read().decode().strip()
    if out:
        print(f'   OK: {out}')
    else:
        print('   Still not started, check logs...')
        stdin, stdout, stderr = client.exec_command('sudo journalctl -u lumenim-comet -n 10 --no-pager', timeout=10)
        print(stdout.read().decode())

# 5. Final check
print('\n[4] Final port check:')
stdin, stdout, stderr = client.exec_command('sudo ss -tlnp | grep -E "9501|9502"', timeout=10)
print(stdout.read().decode())

client.close()
print('=' * 60)
print('[Done]')
