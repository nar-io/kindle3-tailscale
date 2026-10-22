#!/bin/sh
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
D=/mnt/us/extensions/tailscale
STATE=/var/local/tailscale/tailscaled.state
echo "=== STATE FILE BEFORE ==="
ls -l "$STATE" 2>&1
echo "=== STOP ==="
"$D/scripts/stop.sh"
sleep 2
echo "=== PS AFTER STOP ==="
ps | grep tailscale | grep -v grep || echo "no tailscaled process"
echo "=== START ==="
"$D/scripts/start.sh"
sleep 6
echo "=== STATUS AFTER RESTART ==="
"$D/bin/tailscale" --socket=/tmp/tailscaled.sock status 2>&1 | head -4
echo "=== IP AFTER RESTART ==="
"$D/bin/tailscale" --socket=/tmp/tailscaled.sock ip -4 2>&1
echo "=== DATA PATH AFTER RESTART ==="
cd "$D/scripts"
python socks-test.py 127.0.0.1 1055 <PEER_1_IP> 22 2>&1
python socks-test.py 127.0.0.1 1055 <PEER_9> 445 2>&1
echo "=== STATE FILE AFTER ==="
ls -l "$STATE" 2>&1
echo "=== AUTH LOG (should have no new URL) ==="
tail -10 "$D/logs/auth.log" 2>&1

