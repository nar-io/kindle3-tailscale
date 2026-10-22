#!/bin/sh
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
# Sample tailscaled CPU and memory over an interval without generating traffic.
D=/mnt/us/extensions/tailscale
PID=$(cat "$D/run/tailscaled.pid" 2>/dev/null)
INTERVAL=${1:-60}

if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then
    echo "tailscaled not running"
    exit 1
fi

u0=$(awk '{print $14}' /proc/$PID/stat)
s0=$(awk '{print $15}' /proc/$PID/stat)
t0=$(awk '{print $1}' /proc/uptime)
v0=$(awk '/^voluntary_ctxt_switches/ {print $2}' /proc/$PID/status)
n0=$(awk '/^nonvoluntary_ctxt_switches/ {print $2}' /proc/$PID/status)
rss0=$(awk '/VmRSS/ {print $2}' /proc/$PID/status)

echo "sampling ${INTERVAL}s (idle)..."
sleep "$INTERVAL"

u1=$(awk '{print $14}' /proc/$PID/stat)
s1=$(awk '{print $15}' /proc/$PID/stat)
t1=$(awk '{print $1}' /proc/uptime)
v1=$(awk '/^voluntary_ctxt_switches/ {print $2}' /proc/$PID/status)
n1=$(awk '/^nonvoluntary_ctxt_switches/ {print $2}' /proc/$PID/status)
rss1=$(awk '/VmRSS/ {print $2}' /proc/$PID/status)

awk -v u0="$u0" -v s0="$s0" -v u1="$u1" -v s1="$s1" -v t0="$t0" -v t1="$t1" \
    -v v0="$v0" -v v1="$v1" -v n0="$n0" -v n1="$n1" \
    -v rss0="$rss0" -v rss1="$rss1" -v iv="$INTERVAL" 'BEGIN {
    ticks = (u1 + s1) - (u0 + s0);
    cpu = ticks / 100.0 / (t1 - t0) * 100.0;
    printf "interval_s=%.1f cpu_ticks=%d cpu_percent=%.3f\n", t1-t0, ticks, cpu;
    printf "rss_start_kb=%d rss_end_kb=%d\n", rss0, rss1;
    printf "voluntary_ctxt_switches=%d (%.2f/s)\n", v1-v0, (v1-v0)/iv;
    printf "nonvoluntary_ctxt_switches=%d (%.2f/s)\n", n1-n0, (n1-n0)/iv;
}'

echo "--- status ---"
grep -e "VmRSS" -e "VmSize" -e "Threads" /proc/$PID/status
echo "--- loadavg ---"
cat /proc/loadavg
echo "--- meminfo ---"
grep -e "MemFree" -e "MemAvailable" -e "Cached" /proc/meminfo 2>/dev/null || grep -e "MemFree" -e "Cached" /proc/meminfo
