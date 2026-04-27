import paramiko
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)

print('[1] Starting lumenim-comet service...')
stdin, stdout, stderr = client.exec_command('sudo systemctl start lumenim-comet', timeout=10)
stdout.channel.recv_exit_status()
print('    Started')

import time
time.sleep(3)

print('\n[2] Checking comet status...')
stdin, stdout, stderr = client.exec_command('systemctl is-active lumenim-comet', timeout=5)
print(f'    {stdout.read().decode().strip()}')

print('\n[3] Checking port 9502...')
stdin, stdout, stderr = client.exec_command('ss -tlnp | grep 9502', timeout=5)
out = stdout.read().decode()
print(out if out else '    Port 9502 not listening')

print('\n[4] Comet service logs:')
stdin, stdout, stderr = client.exec_command('journalctl -u lumenim-comet -n 10 --no-pager', timeout=5)
out = stdout.read().decode()
print(out[:500] if out else '    No logs')

print('\n[5] All LumenIM processes:')
stdin, stdout, stderr = client.exec_command('ps aux | grep lumenim | grep -v grep', timeout=5)
out = stdout.read().decode()
print(out if out else '    None')

client.close()
print('\n[Done]')
