import paramiko
import time

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)

print('=' * 60)
print('502 Error Diagnosis')
print('=' * 60)

# 1. Check all ports
print('\n[1] All LumenIM ports:')
stdin, stdout, stderr = client.exec_command('ss -tlnp | grep -E "9501|9502|80|443"', timeout=5)
print(stdout.read().decode())

# 2. Check nginx status
print('\n[2] Nginx status:')
stdin, stdout, stderr = client.exec_command('systemctl is-active nginx', timeout=5)
print(f'   {stdout.read().decode().strip()}')

# 3. Check lumenim processes
print('\n[3] LumenIM processes:')
stdin, stdout, stderr = client.exec_command('ps aux | grep lumenim | grep -v grep', timeout=5)
out = stdout.read().decode()
print(out if out else '   None')

# 4. Check if ports are listening
print('\n[4] Port 9501 health:')
stdin, stdout, stderr = client.exec_command('curl -s -o /dev/null -w "%{http_code}" http://localhost:9501/api/v1/health', timeout=5)
print(f'   HTTP: {stdout.read().decode().strip()}')

# 5. Try direct backend
print('\n[5] Direct backend test:')
stdin, stdout, stderr = client.exec_command('curl -s http://localhost:9501/api/v1/health', timeout=5)
print(f'   {stdout.read().decode().strip()}')

# 6. Start lumenim if not running
print('\n[6] Check if lumenim http is running:')
stdin, stdout, stderr = client.exec_command('ss -tlnp | grep 9501', timeout=5)
out = stdout.read().decode()
if ':9501' not in out:
    print('   9501 NOT listening - starting...')
    stdin, stdout, stderr = client.exec_command('cd /var/www/lumenim/backend && nohup ./lumenim http --config=/var/www/lumenim/backend/config.yaml > /tmp/http.log 2>&1 &', timeout=5)
    time.sleep(3)
    
    stdin, stdout, stderr = client.exec_command('ss -tlnp | grep 9501', timeout=5)
    out = stdout.read().decode()
    print(f'   After start: {out.strip() if out else "Still not running"}')
else:
    print('   9501 is listening')

# 7. Start comet if not running
print('\n[7] Check if lumenim comet is running:')
stdin, stdout, stderr = client.exec_command('ss -tlnp | grep 9502', timeout=5)
out = stdout.read().decode()
if ':9502' not in out:
    print('   9502 NOT listening - starting...')
    stdin, stdout, stderr = client.exec_command('cd /var/www/lumenim/backend && nohup ./lumenim comet --config=/var/www/lumenim/backend/config.yaml > /tmp/comet.log 2>&1 &', timeout=5)
    time.sleep(3)
    
    stdin, stdout, stderr = client.exec_command('ss -tlnp | grep 9502', timeout=5)
    out = stdout.read().decode()
    print(f'   After start: {out.strip() if out else "Still not running"}')
else:
    print('   9502 is listening')

# 8. Final health check
print('\n[8] Final health check:')
stdin, stdout, stderr = client.exec_command('curl -s http://localhost:9501/api/v1/health', timeout=5)
print(f'   {stdout.read().decode().strip()}')

client.close()
print('\n' + '=' * 60)
