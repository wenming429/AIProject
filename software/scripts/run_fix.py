import paramiko
import time

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=15)
print('[OK] Connected')

# Start comet
print('[1] Starting comet...')
stdin, stdout, stderr = client.exec_command('sudo systemctl start lumenim-comet', timeout=5)
stdout.channel.recv_exit_status()
print('    Started')

# Wait for startup
time.sleep(3)

# Check ports
print('[2] Checking ports 9501/9502...')
stdin, stdout, stderr = client.exec_command('ss -tlnp | grep -E "9501|9502"', timeout=5)
out = stdout.read().decode()
print(out if out else '    No ports')

# Check processes
print('[3] LumenIM processes:')
stdin, stdout, stderr = client.exec_command('ps aux | grep lumenim | grep -v grep', timeout=5)
out = stdout.read().decode()
print(out if out else '    None')

# Check service status
print('[4] Service status:')
stdin, stdout, stderr = client.exec_command('systemctl is-active lumenim-backend lumenim-comet', timeout=5)
out = stdout.read().decode().strip()
print(f'    backend: {out.split()[0]}')
print(f'    comet: {out.split()[1] if len(out.split()) > 1 else "unknown"}')

client.close()
print('[DONE]')
