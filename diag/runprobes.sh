#!/bin/sh
for v in 1.17.13 1.19.13 1.21.13 1.23.12; do
  echo "############ GO $v ############"
  /mnt/us/probe-go$v 2>&1
  echo "RC=$?"
done
echo "############ DMESG TAIL ############"
dmesg | tail -30
