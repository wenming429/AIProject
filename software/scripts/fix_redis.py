import paramiko
import time

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)

print('=' * 60)
print('Fix Redis and Restart Services')
print('=' * 60)

# 1. Check Redis data directory
print('\n[1] Check Redis data directory:')
stdin, stdout, stderr = client.exec_command('ls -la /var/lib/redis/', timeout=5)
print(stdout.read().decode())

# 2. Check disk space
print('\n[2] Disk space:')
stdin, stdout, stderr = client.exec_command('df -h /var/lib/redis', timeout=5)
print(stdout.read().decode())

# 3. Fix Redis permissions
print('\n[3] Fix Redis permissions...')
stdin, stdout, stderr = client.exec_command('sudo chown redis:redis /var/lib/redis && sudo chmod 770 /var/lib/redis', timeout=5)
stdout.channel.recv_exit_status()
print('   Permissions fixed')

# 4. Stop Redis
print('\n[4] Stop Redis...')
stdin, stdout, stderr = client.exec_command('sudo systemctl stop redis-server', timeout=10)
stdout.channel.recv_exit_status()
print('   Stopped')

# 5. Remove old dump file if corrupted
print('\n[5] Check dump file...')
stdin, stdout, stderr = client.exec_command('ls -la /var/lib/redis/dump.rdb 2>/dev/null || echo "No dump file"', timeout=5)
print(stdout.read().decode().strip())

# 6. Start Redis
print('\n[6] Start Redis...')
stdin, stdout, stderr = client.exec_command('sudo systemctl start redis-server', timeout=10)
stdout.channel.recv_exit_status()
time.sleep(2)

# 7. Test Redis
print('\n[7] Test Redis:')
stdin, stdout, stderr = client.exec_command('redis-cli ping', timeout=5)
print(f'   {stdout.read().decode().strip()}')

# 8. Try to set a value (tests write)
print('\n[8] Test write:')
stdin, stdout, stderr = client.exec_command('redis-cli set test_key "ok" && redis-cli get test_key && redis-cli del test_key', timeout=5)
out = stdout.read().decode().strip()
print(f'   {out}')

# 9. If Redis works, start LumenIM
if 'PONG' in out or 'ok' in out:
    print('\n[9] Redis fixed! Starting LumenIM...')
    
    # Start HTTP
    stdin, stdout, stderr = client.exec_command(
        'cd /var/www/lumenim/backend && ./lumenim http --config=/var/www/lumenim/backend/config.yaml > /tmp/http.log 2>&1 &',
        timeout=10
    )
    time.sleep(3)
    
    # Start Comet
    stdin, stdout, stderr = client.exec_command(
        'cd /var/www/lumenim/backend && ./lumenim comet --config=/var/www/lumenim/backend/config.yaml > /tmp/comet.log 2>&1 &',
        timeout=10
    )
    time.sleep(3)
    
    # Check status
    print('\n[10] Final status:')
    stdin, stdout, stderr = client.exec_command('ss -tlnp | grep -E "9501|9502"', timeout=5)
    out = stdout.read().decode()
    print(out if out else '   No ports listening')
    
    # Health check
    print('\n[11] Health check:')
    stdin, stdout, stderr = client.exec_command('curl -s http://localhost:9501/api/v1/health', timeout=5)
    out = stdout.read().decode().strip()
    print(f'   {out if out else "No response"}')
else:
    print('\n[ERROR] Redis still has issues')

client.close()
print('\n' + '=' * 60)
