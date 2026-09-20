package desktop

import (
	"net"
	"testing"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
)

func TestListenerAddress(t *testing.T) {
	tests := []struct {
		encoded string
		host    string
		want    bool
	}{
		{"0100007F", "127.0.0.1", true},
		{"0100007F", "localhost", true},
		{"00000000", "127.0.0.1", true},
		{"0200007F", "127.0.0.1", false},
		{"invalid", "127.0.0.1", false},
	}
	for _, test := range tests {
		if got := listenerAddress(test.encoded, test.host); got != test.want {
			t.Errorf("listenerAddress(%q, %q) = %t, want %t",
				test.encoded, test.host, got, test.want)
		}
	}
}

func TestListeningSocketsFindsLoopbackListener(t *testing.T) {
	listener, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	port := listener.Addr().(*net.TCPAddr).Port
	if sockets := listeningSockets("127.0.0.1", port); len(sockets) == 0 {
		t.Fatal("loopback listener was not found in procfs")
	}
}

func TestLocalProcessRejectsUnverifiedListener(t *testing.T) {
	client, err := syncthing.NewClient(syncthing.Target{
		Endpoint: "http://127.0.0.1",
		Local:    true,
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := (&Bridge{client: client}).localProcess(); err == nil {
		t.Fatal("endpoint without an explicit port was accepted")
	}
}
