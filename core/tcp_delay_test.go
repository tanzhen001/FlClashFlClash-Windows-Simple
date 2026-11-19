package core

import (
	"context"
	"net"
	"testing"
	"time"
)

func TestTCPConnectDelay(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	delay, err := tcpConnectDelay(ctx, listener.Addr().String())
	if err != nil || delay == 0 {
		t.Fatalf("TCP connection: delay=%d, error=%v", delay, err)
	}
}

func TestTCPConnectDelayFailure(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := tcpConnectDelay(ctx, "127.0.0.1:1"); err == nil {
		t.Fatal("canceled connection succeeded")
	}
	if _, err := tcpConnectDelay(context.Background(), ""); err == nil {
		t.Fatal("empty endpoint succeeded")
	}
}
