import paramiko
import time

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)

print('=' * 60)
print('Direct Start Test')
print('=' * 60)

# Kill any existing
print('\n[1] Clean up:')
client.exec_command('sudo killall lumenim 2>/dev/null', timeout=5)
time.sleep(1)
print('   Done')

# Direct start with output capture
print('\n[2] Starting with output capture...')
stdin, stdout, stderr = client.exec_command(
    'cd /var/www/lumenim/backend && ./lumenim comet --config=/var/www/lumenim/backend/config.yaml 2>&1',
    timeout=5
)

time.sleep(5)

# Check port
print('\n[3] Check port 9502:')
stdin, stdout, stderr = client.exec_command('ss -tlnp | grep 9502', timeout=5)
out = stdout.read().decode()
print(out if out else '   Not listening')

# Check process
print('\n[4] Process:')
stdin, stdout, stderr = client.exec_command('ps aux | grep lumenim | grep -v grep', timeout=5)
print(stdout.read().decode())

# Try systemctl again
print('\n[5] Try systemctl start again:')
stdin, stdout, stderr = client.exec_command('sudo systemctl start lumenim-comet', timeout=10)
stdout.channel.recv_exit_status()
time.sleep(3)

stdin, stdout, stderr = client.exec_command('systemctl is-active lumenim-comet', timeout=5)
print(f'   {stdout.read().decode().strip()}')

# Final port check
print('\n[6] Final port check:')
stdin, stdout, stderr = client.exec_command('ss -tlnp | grep -E "9501|9502"', timeout=5)
print(stdout.read().decode())

client.close()
print('\n' + '=' * 60)
