import paramiko, time
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect('192.168.23.131', 22, 'wenming429', 'wenming429', timeout=20)

print('[1] Restart Redis...')
c.exec_command('sudo systemctl restart redis-server', timeout=10)
time.sleep(2)
s,o,e = c.exec_command('redis-cli ping')
print(f'   {o.read().decode().strip()}')

print('[2] Start HTTP...')
c.exec_command('cd /var/www/lumenim/backend && sudo ./lumenim http --config=/var/www/lumenim/backend/config.yaml &', timeout=10)
time.sleep(5)

print('[3] Start Comet...')
c.exec_command('cd /var/www/lumenim/backend && sudo ./lumenim comet --config=/var/www/lumenim/backend/config.yaml &', timeout=10)
time.sleep(5)

print('[4] Check ports:')
s,o,e = c.exec_command('ss -tlnp | grep -E "9501|9502"')
print(o.read().decode() or '   None')

print('[5] Health:')
s,o,e = c.exec_command('curl -s http://localhost:9501/api/v1/health')
print(f'   {o.read().decode().strip()}')
c.close()
print('[Done]')
