package main

import (
	"crypto/tls"
	"fmt"
	"io"
	"net"
	"os"
	"runtime"
	"time"
)

func main() {
	fmt.Printf("PROBE_START go=%s os=%s arch=%s cpus=%d\n", runtime.Version(), runtime.GOOS, runtime.GOARCH, runtime.NumCPU())

	// Goroutine scheduling + timers
	ch := make(chan int, 1)
	go func() {
		time.Sleep(20 * time.Millisecond)
		ch <- 42
	}()
	fmt.Printf("GOROUTINE=%d\n", <-ch)

	// File I/O + rename + fsync
	fn := "/tmp/goprobe.tmp"
	if err := os.WriteFile(fn, []byte("hello"), 0644); err != nil {
		fmt.Printf("FILE_WRITE_ERR=%v\n", err)
	} else if err := os.Rename(fn, "/tmp/goprobe.txt"); err != nil {
		fmt.Printf("FILE_RENAME_ERR=%v\n", err)
	} else {
		fmt.Printf("FILE_OK\n")
	}
	os.Remove("/tmp/goprobe.txt")

	// TCP loopback: exercises epoll/netpoll/eventfd/accept/socket syscalls
	ln, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		fmt.Printf("LISTEN_ERR=%v\n", err)
	} else {
		fmt.Printf("LISTEN_OK addr=%s\n", ln.Addr())
		go func() {
			c, e := ln.Accept()
			if e == nil {
				io.Copy(c, c)
				c.Close()
			}
		}()
		c, e := net.Dial("tcp4", ln.Addr().String())
		if e != nil {
			fmt.Printf("DIAL_ERR=%v\n", e)
		} else {
			c.SetDeadline(time.Now().Add(5 * time.Second))
			c.Write([]byte("ping"))
			buf := make([]byte, 4)
			_, e = io.ReadFull(c, buf)
			fmt.Printf("TCP_ECHO=%q err=%v\n", string(buf), e)
			c.Close()
		}
		ln.Close()
	}

	// Pure-Go DNS resolution
	t0 := time.Now()
	ips, err := net.LookupHost("controlplane.tailscale.com")
	fmt.Printf("DNS err=%v ips=%v dur=%s\n", err, ips, time.Since(t0))

	// TLS: exercises crypto, /dev/urandom, getrandom fallback, system roots, clock
	d := &net.Dialer{Timeout: 15 * time.Second}
	t1 := time.Now()
	conn, err := tls.DialWithDialer(d, "tcp", "controlplane.tailscale.com:443", &tls.Config{
		ServerName: "controlplane.tailscale.com",
	})
	if err != nil {
		fmt.Printf("TLS_ERR=%v dur=%s\n", err, time.Since(t1))
	} else {
		st := conn.ConnectionState()
		fmt.Printf("TLS_OK version=%x cipher=%x dur=%s\n", st.Version, st.CipherSuite, time.Since(t1))
		conn.Close()
	}

	fmt.Printf("PROBE_DONE\n")
}
