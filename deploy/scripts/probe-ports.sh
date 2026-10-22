#!/bin/sh
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
cd /mnt/us/extensions/tailscale/scripts
for hp in "<PEER_1_IP> 80" "<PEER_1_IP> 443" "<PEER_1_IP> 8080" "<PEER_1_IP> 3000" "<PEER_1_IP> 8123" "<PEER_1_IP> 9000" "<PEER_8_IP> 80" "<PEER_8_IP> 8080" "<PEER_8_IP> 3389" "<PEER_19_IP> 443" "<PEER_19_IP> 8080"; do
    set -- $hp
    printf "%s:%s  " "$1" "$2"
    python socks-test.py 127.0.0.1 1055 "$1" "$2" 2>&1 | tail -1
done

