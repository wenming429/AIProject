import paramiko
import time

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)

print('=' * 60)
print('Fix Redis & Start Services (with sudo)')
print('=' * 60)

# 1. Fix Redis permissions
print('\n[1] Fix Redis permissions...')
stdin, stdout, stderr = client.exec_command('sudo chown redis:redis /var/lib/redis && sudo chmod 770 /var/lib/redis', timeout=10)
stdout.channel.recv_exit_status()
print('   Done')

# 2. Restart Redis
print('\n[2] Restart Redis...')
stdin, stdout, stderr = client.exec_command('sudo systemctl restart redis-server', timeout=15)
stdout.channel.recv_exit_status()
time.sleep(2)

stdin, stdout, stderr = client.exec_command('redis-cli ping', timeout=5)
pong = stdout.read().decode().strip()
print(f'   Redis: {pong}')

# 3. Test Redis write
print('\n[3] Test Redis write...')
stdin, stdout, stderr = client.exec_command('redis-cli set test_ok 1 && redis-cli del test_ok', timeout=5)
print(f'   Write test: OK')

# 4. Start HTTP service with sudo
print('\n[4] Start HTTP service...')
stdin, stdout, stderr = client.exec_command(
    'sudo cd /var/www/lumenim/backend && sudo ./lumenim http --config=/var/www/lumenim/backend/config.yaml > /tmp/http.log 2>&1 &',
    timeout=10
)
stdout.channel.recv_exit_status()
time.sleep(5)

# 5. Start Comet service with sudo
print('\n[5] Start Comet service...')
stdin, stdout, stderr = client.exec_command(
    'sudo cd /var/www/lumenim/backend && sudo ./lumenim comet --config=/var/www/lumenim/backend/config.yaml > /tmp/comet.log 2>&1 &',
    timeout=10
)
stdout.channel.recv_exit_status()
time.sleep(5)

# 6. Check status
print('\n[6] Final status:')
stdin, stdout, stderr = client.exec_command('ss -tlnp | grep -E "9501|9502"', timeout=5)
out = stdout.read().decode()
print(out if out else '   No ports')

# 7. Check processes
print('\n[7] LumenIM processes:')
stdin, stdout, stderr = client.exec_command('ps aux | grep lumenim | grep -v grep', timeout=5)
print(stdout.read().decode())

# 8. Health check
print('\n[8] Health check:')
stdin, stdout, stderr = client.exec_command('curl -s http://localhost:9501/api/v1/health', timeout=5)
print(f'   {stdout.read().decode().strip()}')

client.close()
print('\n' + '=' * 60)
