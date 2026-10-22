#!/bin/sh
# Read-only <PEER_8> 3 diagnostic script. Makes no changes.
echo "=== DATE ==="
date 2>&1
echo "=== UNAME ==="
uname -a 2>&1
echo "=== CPUINFO ==="
cat /proc/cpuinfo 2>&1
echo "=== MEMINFO ==="
cat /proc/meminfo 2>&1
echo "=== VERSION ==="
cat /proc/version 2>&1
echo "=== CMDLINE ==="
cat /proc/cmdline 2>&1
echo "=== UPTIME ==="
cat /proc/uptime 2>&1
echo "=== DF ==="
df -h 2>&1
echo "=== DF_K ==="
df -k 2>&1
echo "=== MOUNT ==="
mount 2>&1
echo "=== PARTITIONS ==="
cat /proc/partitions 2>&1
echo "=== LIBC ==="
ls -l /lib/libc* /lib/ld-* /lib/ld-linux* /lib/libpthread* /lib/libm* 2>&1
/lib/libc.so.6 2>&1 | head -5
echo "=== LIBC_STRINGS ==="
strings /lib/libc.so.6 2>/dev/null | grep -i -m 5 "GNU C Library\|release version" 2>&1
echo "=== OSRELEASE ==="
cat /etc/os-release 2>&1
cat /etc/issue 2>&1
echo "=== IP ==="
ifconfig -a 2>&1
echo "=== ROUTE ==="
route -n 2>&1
cat /proc/net/route 2>&1
echo "=== DNS ==="
cat /etc/resolv.conf 2>&1
echo "=== HOSTS ==="
cat /etc/hosts 2>&1
echo "=== TUN_DEV ==="
ls -l /dev/net /dev/net/tun /dev/tun 2>&1
echo "=== DEV_NET_LIST ==="
ls -la /dev 2>&1 | head -60
echo "=== TUN_MODULE_SEARCH ==="
find /lib/modules -name "*tun*" 2>/dev/null
ls -la /lib/modules 2>&1
echo "=== LSmod ==="
lsmod 2>&1
cat /proc/modules 2>&1
echo "=== MODULES_BUILTIN ==="
grep -i "tun\|bridge" /lib/modules/*/modules.builtin 2>/dev/null
echo "=== KCONFIG ==="
ls -l /proc/config.gz /boot/config* 2>&1
zcat /proc/config.gz 2>/dev/null | grep -i "CONFIG_TUN\|CONFIG_NETFILTER\|CONFIG_INET\|CONFIG_IPV6" 2>&1
echo "=== TUN_IN_PROC ==="
grep -i tun /proc/misc 2>&1
cat /proc/misc 2>&1
echo "=== TUN_TEST_READONLY ==="
ls -l /sys/class/net 2>&1
echo "=== NETDEV ==="
cat /proc/net/dev 2>&1
echo "=== TOOLS ==="
for t in sh bash ash busybox gcc cc g++ ld make python python2 python3 pip perl wget curl tar gzip gunzip xz unzip scp sftp nc telnet openssl iptables ip ifconfig route nslookup ping insmod modprobe dmesg; do
  p=$(which $t 2>/dev/null)
  if [ -n "$p" ]; then echo "$t: $p"; else echo "$t: MISSING"; fi
done
echo "=== BUSYBOX ==="
busybox 2>&1 | head -5
echo "=== GCC_VER ==="
gcc --version 2>&1 | head -3
ld --version 2>&1 | head -3
echo "=== PYTHON_VER ==="
python --version 2>&1
python2 --version 2>&1
echo "=== OPENSSL ==="
openssl version 2>&1
echo "=== WRITABLE ==="
touch /mnt/us/.diag_write_test 2>&1 && echo "/mnt/us WRITABLE" && rm -f /mnt/us/.diag_write_test
touch /tmp/.diag_write_test 2>&1 && echo "/tmp WRITABLE" && rm -f /tmp/.diag_write_test
touch /var/tmp/.diag_write_test 2>&1 && echo "/var/tmp WRITABLE" && rm -f /var/tmp/.diag_write_test
mount | grep -E " /mnt/us | /tmp | / " 2>&1
echo "=== USB_DIRS ==="
ls -la /mnt/us 2>&1 | head -40
ls -la /mnt/us/extensions 2>&1 | head -20
echo "=== EXISTING_TAILSCALE ==="
ls -la /mnt/us/extensions/tailscale 2>&1
find /mnt/us -maxdepth 4 -iname "*tailscale*" 2>/dev/null
echo "=== KUAL ==="
ls -la /mnt/us/extensions 2>&1
cat /mnt/us/extensions/*/config.xml 2>/dev/null | head -40
echo "=== LAUNCHER ==="
ls -la /etc/init.d 2>&1
ls -la /etc/rc*.d 2>&1 | head -80
cat /etc/init.d/rcS 2>&1 | head -40
echo "=== POWER ==="
ls -la /sys/class/power_supply 2>&1
cat /sys/class/power_supply/*/capacity 2>&1
echo "=== KERNEL_SYSCALLS ==="
cat /proc/sys/kernel/osrelease 2>&1
cat /proc/sys/net/ipv4/ip_forward 2>&1
echo "=== NET_NAMESPACES ==="
ls -l /proc/self/ns 2>&1
echo "=== CGROUPS ==="
cat /proc/cgroups 2>&1
mount | grep cgroup 2>&1
echo "=== FILESYSTEMS ==="
cat /proc/filesystems 2>&1
echo "=== SECCOMP ==="
grep -i seccomp /proc/self/status 2>&1
echo "=== LIMITS ==="
ulimit -a 2>&1
echo "=== END ==="

