#!/bin/sh
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
cd /mnt/us/extensions/tailscale/scripts
echo "=== SOCKS5 HTTP IP ==="
python socks-test.py 127.0.0.1 1055 <PEER_8_IP> 18080 http
echo "=== SOCKS5 HTTP MagicDNS ==="
python socks-test.py 127.0.0.1 1055 <PEER_9> 18080 http
echo "=== HTTP PROXY IP ==="
curl -x http://127.0.0.1:1056 -m 15 -sS -D - http://<PEER_8_IP>:18080/ 2>&1 | head -12
echo "=== HTTP PROXY MagicDNS ==="
curl -x http://127.0.0.1:1056 -m 15 -sS -D - http://<PEER_9>:18080/ 2>&1 | head -12

