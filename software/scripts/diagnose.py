import paramiko
import time

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)

print('=' * 60)
print('Diagnose Systemd Issue')
print('=' * 60)

# 1. Stop any running lumenim
print('\n[1] Stop any running lumenim:')
stdin, stdout, stderr = client.exec_command('sudo killall lumenim 2>/dev/null; sleep 1', timeout=5)
stdout.channel.recv_exit_status()
print('   Done')

# 2. Try to start and get immediate output
print('\n[2] Start service and check immediately:')
stdin, stdout, stderr = client.exec_command('sudo systemctl start lumenim-comet 2>&1', timeout=10)
stdout.channel.recv_exit_status()
err = stderr.read().decode()
out = stdout.read().decode()
print(f'   stdout: {out}')
print(f'   stderr: {err}')

time.sleep(2)

# 3. Check status with full output
print('\n[3] Full status after start:')
stdin, stdout, stderr = client.exec_command('systemctl status lumenim-comet --no-pager -l 2>&1', timeout=10)
print(stdout.read().decode()[:1000])

# 4. Check journal logs
print('\n[4] Journal logs:')
stdin, stdout, stderr = client.exec_command('journalctl -u lumenim-comet -n 20 --no-pager 2>&1', timeout=10)
out = stdout.read().decode()
print(out if out else '   No logs')

# 5. Check if port is listening
print('\n[5] Check port 9502:')
stdin, stdout, stderr = client.exec_command('ss -tlnp | grep 9502', timeout=5)
out = stdout.read().decode()
print(out if out else '   Not listening')

# 6. Check process
print('\n[6] Process check:')
stdin, stdout, stderr = client.exec_command('ps aux | grep lumenim', timeout=5)
print(stdout.read().decode())

# 7. Try manual start to compare
print('\n[7] Manual start for comparison:')
stdin, stdout, stderr = client.exec_command('cd /var/www/lumenim/backend && ./lumenim comet &', timeout=5)
time.sleep(3)

stdin, stdout, stderr = client.exec_command('ss -tlnp | grep 9502', timeout=5)
out = stdout.read().decode()
print(f'   Port 9502: {out.strip() if out else "Not listening"}')

client.close()
print('\n' + '=' * 60)
