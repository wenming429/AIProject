import paramiko
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)

print('=' * 60)
print('Systemd Debug')
print('=' * 60)

# Check why systemd fails
print('\n[1] Stop manual process first:')
stdin, stdout, stderr = client.exec_command('sudo killall lumenim 2>/dev/null; sleep 1', timeout=5)
stdout.channel.recv_exit_status()
print('   Killed')

print('\n[2] Systemd start with full output:')
stdin, stdout, stderr = client.exec_command('sudo systemd-run --scope -p StandardOutput=file:/tmp/comet_debug.log -p StandardError=file:/tmp/comet_debug.log --unit=lumenim-comet /var/www/lumenim/backend/lumenim comet --config=/var/www/lumenim/backend/config.yaml 2>&1', timeout=10)
out = stdout.read().decode()
err = stderr.read().decode()
print(f'stdout: {out}')
print(f'stderr: {err}')

import time
time.sleep(3)

print('\n[3] Check process:')
stdin, stdout, stderr = client.exec_command('ps aux | grep lumenim | grep -v grep', timeout=5)
print(stdout.read().decode())

print('\n[4] Check port 9502:')
stdin, stdout, stderr = client.exec_command('ss -tlnp | grep 9502', timeout=5)
out = stdout.read().decode()
print(out if out else '   Not listening')

print('\n[5] Check debug log:')
stdin, stdout, stderr = client.exec_command('cat /tmp/comet_debug.log 2>/dev/null || echo "No log"', timeout=5)
print(stdout.read().decode()[:500])

print('\n[6] Check journalctl for errors:')
stdin, stdout, stderr = client.exec_command('journalctl -xe --no-pager | tail -20', timeout=5)
print(stdout.read().decode())

client.close()
print('\n' + '=' * 60)
