#!/bin/sh
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
DIR=/mnt/us/extensions/tailscale
echo "=== tailscaled.log (last 80) ==="
tail -80 "$DIR/logs/tailscaled.log" 2>&1
echo "=== auth.log ==="
cat "$DIR/logs/auth.log" 2>&1
