#!/bin/sh
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
# One-time migration: move node state from vfat (/mnt/us) to ext3 (/var/local)
# so the private key can be mode 0600. Already applied on this device.
# Kept for documentation; it is a no-op once the new state file exists.
D=/mnt/us/extensions/tailscale
OLD="$D/state/tailscaled.state"
NEWDIR=/var/local/tailscale
NEW="$NEWDIR/tailscaled.state"

echo "=== STOP ==="
"$D/scripts/stop.sh"
echo "=== MOVE STATE ==="
mkdir -p "$NEWDIR"
chmod 700 "$NEWDIR"
if [ ! -f "$NEW" ]; then
    cp "$OLD" "$NEW"
fi
chmod 600 "$NEW"
ls -ld "$NEWDIR"
ls -l "$NEW"
echo "=== START WITH NEW STATE PATH ==="
"$D/scripts/start.sh"
sleep 6
"$D/bin/tailscale" --socket=/tmp/tailscaled.sock status 2>&1 | head -3
"$D/bin/tailscale" --socket=/tmp/tailscaled.sock ip -4 2>&1
cd "$D/scripts"
python socks-test.py 127.0.0.1 1055 <PEER_1_IP> 22 2>&1
echo "=== STATE PERMS ==="
ls -l "$NEW"
echo "=== REMOVE OLD WORLD-READABLE COPY ==="
rm -f "$OLD"
ls -la "$D/state" 2>&1

