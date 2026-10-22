#!/bin/sh
echo "=== DATE_EPOCH ==="
date +%s
echo "=== NTPS ==="
ps 2>/dev/null | grep -i "ntp\|date\|chrony" | grep -v grep
ls -l /usr/bin/ntpdate /usr/sbin/ntpdate 2>&1
echo "=== KCONFIG_RELEVANT ==="
zcat /proc/config.gz 2>/dev/null | grep -i "CONFIG_EPOLL\|CONFIG_EVENTFD\|CONFIG_TIMERFD\|CONFIG_FUTEX\|CONFIG_INOTIFY\|CONFIG_NET_NS\|CONFIG_NAMESPACES\|CONFIG_SECCOMP\|CONFIG_CGROUPS\|CONFIG_BPF\|CONFIG_NETFILTER\|CONFIG_TUN\|CONFIG_VETH\|CONFIG_BRIDGE\|CONFIG_DUMMY\|CONFIG_VLAN\|CONFIG_IPV6\|CONFIG_IP_MULTIPLE_TABLES\|CONFIG_IP_ROUTE_MULTIPATH\|CONFIG_IP_ADVANCED_ROUTER\|CONFIG_PACKET\|CONFIG_UNIX\|CONFIG_INET_DIAG\|CONFIG_TCP_CONG\|CONFIG_ARM_THUMB\|CONFIG_VFP\|CONFIG_NEON\|CONFIG_SMP\|CONFIG_PREEMPT\|CONFIG_HZ="
echo "=== PROBE_FILES ==="
ls -l /mnt/us/armv6_probe /mnt/us/aarch64_probe 2>&1
echo "--- armv6_probe strings ---"
strings /mnt/us/armv6_probe 2>/dev/null | grep -i -m 8 "go1\.\|go build\|version\|usage" 
echo "--- run armv6_probe ---"
/mnt/us/armv6_probe 2>&1 | head -20
echo "exit=$?"
echo "=== EXEC_TEST_MNT_US ==="
cp /bin/busybox /mnt/us/.exec_test 2>&1 && chmod +x /mnt/us/.exec_test && /mnt/us/.exec_test echo "EXEC_FROM_MNT_US_OK" 2>&1; rm -f /mnt/us/.exec_test
echo "=== EXEC_TEST_TMP ==="
cp /bin/busybox /tmp/.exec_test 2>&1 && chmod +x /tmp/.exec_test && /tmp/.exec_test echo "EXEC_FROM_TMP_OK" 2>&1; rm -f /tmp/.exec_test
echo "=== EXEC_TEST_VARLOCAL ==="
cp /bin/busybox /var/local/.exec_test 2>&1 && chmod +x /var/local/.exec_test && /var/local/.exec_test echo "EXEC_FROM_VARLOCAL_OK" 2>&1; rm -f /var/local/.exec_test
echo "=== INTERNET ==="
ping -c 2 -W 3 1.1.1.1 2>&1
wget -q -T 8 -O /tmp/.ts_home http://tailscale.com/ 2>&1; echo "wget_http_exit=$?"; ls -l /tmp/.ts_home 2>&1; rm -f /tmp/.ts_home
wget -q -T 8 -O /tmp/.ts_home2 http://controlplane.tailscale.com/ 2>&1; echo "wget_cp_exit=$?"; ls -l /tmp/.ts_home2 2>&1; rm -f /tmp/.ts_home2
echo "=== DNS_RESOLVE ==="
nslookup controlplane.tailscale.com 2>&1 | head -20
echo "=== TLS_TEST ==="
echo | openssl s_client -connect controlplane.tailscale.com:443 -servername controlplane.tailscale.com 2>&1 | head -25
echo "=== PIP ==="
python -c "import pip; print(pip.__version__)" 2>&1
python -m pip --version 2>&1
echo "=== PY_SSL ==="
python -c "import ssl; print(ssl.OPENSSL_VERSION)" 2>&1
echo "=== UDEV ==="
ls -l /etc/udev/rules.d 2>&1 | head
echo "=== MODULE_DIR ==="
find /lib/modules -type f 2>/dev/null | head -30
echo "=== KERNEL_EXTRAS ==="
ls -l /lib/modules/2.6.26-rt-lab126 2>&1
ls -l /lib/modules/2.6.26-rt-lab126/kernel 2>&1
find /lib/modules/2.6.26-rt-lab126 -name "*.ko" 2>/dev/null | head -40
echo "=== SYSCALL_CHECK ==="
cat /proc/sys/kernel/randomize_va_space 2>&1
cat /proc/sys/vm/overcommit_memory 2>&1
echo "=== TUN_OPEN_TEST_DEFERRED ==="
echo "not opened"
echo "=== END2 ==="
