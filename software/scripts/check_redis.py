import paramiko
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)

print('=' * 60)
print('Redis Debug')
print('=' * 60)

# Check Redis log
print('\n[1] Redis error log:')
s,o,e = c.exec_command('sudo journalctl -u redis-server -n 20 --no-pager', timeout=10)
print(o.read().decode()[:1000])

# Check Redis config
print('\n[2] Redis save config:')
s,o,e = c.exec_command('redis-cli config get save', timeout=5)
print(o.read().decode())

# Check data dir
print('\n[3] Data directory:')
s,o,e = c.exec_command('ls -la /var/lib/redis/', timeout=5)
print(o.read().decode())

s,o,e = c.exec_command('df -h /var/lib/redis', timeout=5)
print(o.read().decode())

# Check Redis config file
print('\n[4] Redis config:')
s,o,e = c.exec_command('cat /etc/redis/redis.conf | grep -E "dir|dbfilename|stop-writes-on-bgsave-error"', timeout=5)
print(o.read().decode())

# Try to fix by disabling bgsave
print('\n[5] Fix: Disable stop-writes-on-bgsave-error...')
s,o,e = c.exec_command('redis-cli config set stop-writes-on-bgsave-error no', timeout=5)
print(f'   {o.read().decode().strip()}')

# Test again
print('\n[6] Test Redis:')
s,o,e = c.exec_command('redis-cli ping', timeout=5)
print(f'   {o.read().decode().strip()}')

s,o,e = c.exec_command('redis-cli set test 1', timeout=5)
print(f'   Set test: {o.read().decode().strip()}')

# Now start lumenim
print('\n[7] Start LumenIM HTTP...')
s,o,e = c.exec_command('cd /var/www/lumenim/backend && ./lumenim http --config=/var/www/lumenim/backend/config.yaml &', timeout=10)
import time; time.sleep(5)

print('\n[8] Start LumenIM Comet...')
s,o,e = c.exec_command('cd /var/www/lumenim/backend && ./lumenim comet --config=/var/www/lumenim/backend/config.yaml &', timeout=10)
import time; time.sleep(5)

print('\n[9] Check ports:')
s,o,e = c.exec_command('ss -tlnp | grep -E "9501|9502"')
print(o.read().decode() or '   None')

print('\n[10] Health:')
s,o,e = c.exec_command('curl -s http://localhost:9501/api/v1/health')
print(f'   {o.read().decode().strip()}')

c.close()
print('\n' + '=' * 60)
