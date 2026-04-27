import paramiko
import time

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)

print('=' * 60)
print('Starting LumenIM Services')
print('=' * 60)

# Start HTTP service
print('\n[1] Starting HTTP service (9501)...')
stdin, stdout, stderr = client.exec_command(
    'cd /var/www/lumenim/backend && ./lumenim http --config=/var/www/lumenim/backend/config.yaml > /tmp/http.log 2>&1 &',
    timeout=10
)
print('   Started')
time.sleep(5)

# Check HTTP
stdin, stdout, stderr = client.exec_command('ss -tlnp | grep 9501', timeout=5)
out = stdout.read().decode()
print(f'   Port 9501: {"OK" if ":9501" in out else "FAILED"}')

# Start Comet service
print('\n[2] Starting WebSocket service (9502)...')
stdin, stdout, stderr = client.exec_command(
    'cd /var/www/lumenim/backend && ./lumenim comet --config=/var/www/lumenim/backend/config.yaml > /tmp/comet.log 2>&1 &',
    timeout=10
)
print('   Started')
time.sleep(5)

# Check Comet
stdin, stdout, stderr = client.exec_command('ss -tlnp | grep 9502', timeout=5)
out = stdout.read().decode()
print(f'   Port 9502: {"OK" if ":9502" in out else "FAILED"}')

# Health check
print('\n[3] Health check:')
stdin, stdout, stderr = client.exec_command('curl -s http://localhost:9501/api/v1/health', timeout=5)
out = stdout.read().decode().strip()
print(f'   {out if out else "No response"}')

# Final status
print('\n[4] Final status:')
stdin, stdout, stderr = client.exec_command('ss -tlnp | grep -E "9501|9502"', timeout=5)
print(stdout.read().decode())

# Processes
print('\n[5] Running processes:')
stdin, stdout, stderr = client.exec_command('ps aux | grep lumenim | grep -v grep', timeout=5)
print(stdout.read().decode())

client.close()
print('\n' + '=' * 60)
print('Done! Services should be running.')
print('=' * 60)
