#!/usr/bin/env python
# Minimal SOCKS5 client for testing Tailscale userspace-networking.
# Python 2.7 compatible (<PEER_8> stock Python).
# Usage: socks-test.py PROXY_HOST PROXY_PORT TARGET_HOST TARGET_PORT [http]
import socket
import struct
import sys


def recvn(s, n):
    buf = b""
    while len(buf) < n:
        chunk = s.recv(n - len(buf))
        if not chunk:
            raise IOError("connection closed")
        buf += chunk
    return buf


def main():
    if len(sys.argv) < 5:
        print("usage: socks-test.py PROXY_HOST PROXY_PORT TARGET_HOST TARGET_PORT [http]")
        return 2
    ph, pp, th, tp = sys.argv[1], int(sys.argv[2]), sys.argv[3], int(sys.argv[4])
    do_http = len(sys.argv) > 5 and sys.argv[5] == "http"

    s = socket.create_connection((ph, pp), 10)
    s.settimeout(15)
    s.sendall(b"\x05\x01\x00")
    greeting = recvn(s, 2)
    if greeting != b"\x05\x00":
        print("SOCKS5 greeting rejected: %r" % (greeting,))
        return 1

    try:
        socket.inet_aton(th)
        addr = b"\x01" + socket.inet_aton(th)
    except socket.error:
        addr = b"\x03" + chr(len(th)) + th
    req = b"\x05\x01\x00" + addr + struct.pack("!H", tp)
    s.sendall(req)
    rep = recvn(s, 4)
    if ord(rep[0]) != 5 or ord(rep[1]) != 0:
        print("SOCKS5 CONNECT failed: ver=%d rep=%d" % (ord(rep[0]), ord(rep[1])))
        return 1
    atyp = ord(rep[3])
    if atyp == 1:
        recvn(s, 4)
    elif atyp == 3:
        recvn(s, ord(recvn(s, 1)))
    elif atyp == 4:
        recvn(s, 16)
    recvn(s, 2)
    print("SOCKS5 CONNECT OK -> %s:%d" % (th, tp))

    if do_http:
        s.sendall("GET / HTTP/1.0\r\nHost: %s\r\n\r\n" % th)
        data = s.recv(512)
        first = data.split("\r\n")[0]
        print("HTTP first line: %s" % first)
        print("HTTP bytes: %d" % len(data))
    s.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())

