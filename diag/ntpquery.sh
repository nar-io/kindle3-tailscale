#!/bin/sh
echo "=== BEFORE ==="
date
date -u
echo "=== NTP_QUERY ==="
ntpdate -q pool.ntp.org 2>&1
echo "rc=$?"
echo "=== NTP_QUERY_GOOGLE ==="
ntpdate -q time.google.com 2>&1
echo "rc=$?"
