#!/usr/bin/env python3
import paramiko
import time

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)

print('=== Permanent Redis Fix ===')

# 1. Find Redis config file
print('\n[1] Finding Redis config...')
stdin, stdout, stderr = client.exec_command('sudo find /etc -name "redis*.conf" 2>/dev/null', timeout=10)
config_file = stdout.read().decode().strip()
print(f'   Config file: {config_file}')

# 2. Backup config
print('\n[2] Backing up config...')
stdin, stdout, stderr = client.exec_command(f'sudo cp {config_file} {config_file}.bak', timeout=10)
print('   Backup done')

# 3. Check current stop-writes-on-bgsave-error
print('\n[3] Current config:')
stdin, stdout, stderr = client.exec_command(f'sudo grep "stop-writes-on-bgsave-error" {config_file}', timeout=10)
print(stdout.read().decode().strip())

# 4. Fix stop-writes-on-bgsave-error
print('\n[4] Fixing stop-writes-on-bgsave-error...')
stdin, stdout, stderr = client.exec_command(f'sudo sed -i "s/stop-writes-on-bgsave-error yes/stop-writes-on-bgsave-error no/" {config_file}', timeout=10)
print('   Fixed')

# 5. Check dir setting
print('\n[5] Checking dir setting...')
stdin, stdout, stderr = client.exec_command(f'sudo grep "^dir " {config_file}', timeout=10)
current_dir = stdout.read().decode().strip()
print(f'   Current: {current_dir}')

# 6. Set dir to /var/lib/redis if needed
print('\n[6] Ensuring dir is /var/lib/redis...')
stdin, stdout, stderr = client.exec_command('sudo mkdir -p /var/lib/redis && sudo chown redis:redis /var/lib/redis', timeout=10)
stdin, stdout, stderr = client.exec_command(f'sudo sed -i "s|^dir .*|dir /var/lib/redis|" {config_file}', timeout=10)
print('   Done')

# 7. Verify changes
print('\n[7] Verify changes:')
stdin, stdout, stderr = client.exec_command(f'sudo grep -E "stop-writes-on-bgsave-error|^dir " {config_file}', timeout=10)
print(stdout.read().decode())

# 8. Restart Redis
print('\n[8] Restarting Redis...')
stdin, stdout, stderr = client.exec_command('sudo systemctl restart redis-server', timeout=10)
time.sleep(2)

# 9. Test Redis
print('\n[9] Testing Redis:')
stdin, stdout, stderr = client.exec_command('sudo redis-cli ping', timeout=10)
print(f'   ping: {stdout.read().decode().strip()}')

stdin, stdout, stderr = client.exec_command('sudo redis-cli SET test OK && sudo redis-cli GET test', timeout=10)
print(f'   write: {stdout.read().decode().strip()}')

# 10. Restart LumenIM services
print('\n[10] Restarting LumenIM services...')
stdin, stdout, stderr = client.exec_command('sudo pkill -f lumenim', timeout=5)
time.sleep(1)
stdin, stdout, stderr = client.exec_command('cd /var/www/lumenim/backend && sudo ./lumenim http > /tmp/http.log 2>&1 &', timeout=5)
time.sleep(2)
stdin, stdout, stderr = client.exec_command('cd /var/www/lumenim/backend && sudo ./lumenim comet > /tmp/comet.log 2>&1 &', timeout=5)
time.sleep(3)

# 11. Final check
print('\n[11] Final service status:')
stdin, stdout, stderr = client.exec_command('sudo ss -tlnp | grep -E "9501|9502|6379"', timeout=10)
print(stdout.read().decode())

print('\n[12] Process status:')
stdin, stdout, stderr = client.exec_command('ps aux | grep lumenim | grep -v grep', timeout=10)
print(stdout.read().decode())

client.close()
print('\n=== Done ===')
