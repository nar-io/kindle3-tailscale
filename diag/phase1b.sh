#!/bin/sh
echo "=== EXEC ==="
cp /bin/busybox /mnt/us/busybox_probe && /mnt/us/busybox_probe echo EXEC_MNT_US_OK
cp /bin/busybox /var/local/busybox_probe && /var/local/busybox_probe echo EXEC_VARLOCAL_OK
rm -f /mnt/us/busybox_probe /var/local/busybox_probe
echo "=== TUN_OPEN ==="
python -c "import os
try:
    fd=os.open('/dev/net/tun',os.O_RDWR)
    print('TUN_OPENED fd=%d' % fd)
    os.close(fd)
except OSError as e:
    print('TUN_OPEN_FAILED errno=%d %s' % (e.errno, e.strerror))" 2>&1
echo "=== PROBE_ELF ==="
od -An -tx1 -N20 /mnt/us/armv6_probe
echo "=== PROBE_LDD ==="
ldd /mnt/us/armv6_probe 2>&1 | head -10
echo "=== PROBE_RUN2 ==="
/mnt/us/armv6_probe 2>&1; echo "rc=$?"
echo "=== MEM ==="
free
echo "=== PROC_NET_TUN ==="
cat /proc/net/dev 2>&1
echo "=== END ==="
