#!/bin/sh
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
# Measure tailscaled CPU during a real 16 MB download over the HTTP proxy.
D=/mnt/us/extensions/tailscale
PID=$(cat "$D/run/tailscaled.pid")
u0=$(awk '{print $14}' /proc/$PID/stat)
s0=$(awk '{print $15}' /proc/$PID/stat)
t0=$(awk '{print $1}' /proc/uptime)

echo "downloading 16MB through HTTP proxy..."
res=$(curl -x http://127.0.0.1:1056 -m 180 -sS -o /dev/null -w '%{size_download} %{time_total}' http://<PEER_8_IP>:18081/big 2>&1)
rc=$?

u1=$(awk '{print $14}' /proc/$PID/stat)
s1=$(awk '{print $15}' /proc/$PID/stat)
t1=$(awk '{print $1}' /proc/uptime)

echo "curl_rc=$rc result=$res"
awk -v u0="$u0" -v s0="$s0" -v u1="$u1" -v s1="$s1" -v t0="$t0" -v t1="$t1" 'BEGIN {
    ticks=(u1+s1)-(u0+s0); dur=t1-t0;
    printf "wall_s=%.2f tailscaled_cpu_ticks=%d avg_cpu_percent=%.2f\n", dur, ticks, ticks/100.0/dur*100.0;
}'
grep -e VmRSS /proc/$PID/status

