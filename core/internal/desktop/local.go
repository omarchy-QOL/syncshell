package desktop

import (
	"encoding/binary"
	"encoding/hex"
	"errors"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
)

func listenerAddress(encoded, host string) bool {
	address, err := hex.DecodeString(encoded)
	if err != nil || (len(address) != 4 && len(address) != 16) {
		return false
	}
	for offset := 0; offset < len(address); offset += 4 {
		value := binary.NativeEndian.Uint32(address[offset:])
		binary.BigEndian.PutUint32(address[offset:], value)
	}
	if host == "localhost" {
		host = "127.0.0.1"
	}
	return net.IP(address).IsUnspecified() || net.IP(address).Equal(net.ParseIP(host))
}

// A loopback address can be an SSH tunnel; verify the actual listening process.
func (b *Bridge) localProcess() error {
	endpoint, _ := url.Parse(b.client.Endpoint())
	port, err := strconv.Atoi(endpoint.Port())
	if err != nil {
		return errors.New("local Syncthing listener could not be verified")
	}
	sockets := listeningSockets(endpoint.Hostname(), port)
	if b.pid > 0 && matchesLocalSyncthing(b.pid, sockets) {
		return nil
	}
	entries, _ := os.ReadDir("/proc")
	for _, entry := range entries {
		pid, err := strconv.Atoi(entry.Name())
		if err == nil && matchesLocalSyncthing(pid, sockets) {
			b.pid = pid
			return nil
		}
	}
	b.pid = 0
	return errors.New("file actions require Syncthing on this desktop, under the same user and outside containers or tunnels")
}

func listeningSockets(host string, port int) map[string]bool {
	sockets := map[string]bool{}
	for _, table := range []string{"/proc/net/tcp", "/proc/net/tcp6"} {
		data, _ := os.ReadFile(table)
		for _, line := range strings.Split(string(data), "\n") {
			fields := strings.Fields(line)
			if len(fields) < 10 || fields[3] != "0A" {
				continue
			}
			address, hexPort, _ := strings.Cut(fields[1], ":")
			value, parseErr := strconv.ParseInt(hexPort, 16, 32)
			if parseErr == nil && int(value) == port && listenerAddress(address, host) {
				sockets["socket:["+fields[9]+"]"] = true
			}
		}
	}
	return sockets
}

func matchesLocalSyncthing(pid int, sockets map[string]bool) bool {
	proc := "/proc/" + strconv.Itoa(pid)
	info, err := os.Stat(proc)
	if err != nil || info.Sys().(*syscall.Stat_t).Uid != uint32(os.Geteuid()) {
		return false
	}
	exe, err := os.Readlink(proc + "/exe")
	if err != nil || filepath.Base(exe) != "syncthing" {
		return false
	}
	for _, namespace := range []string{"mnt", "pid", "net"} {
		peer, peerErr := os.Readlink(proc + "/ns/" + namespace)
		self, selfErr := os.Readlink("/proc/self/ns/" + namespace)
		if peerErr != nil || selfErr != nil || peer != self {
			return false
		}
	}
	entries, _ := os.ReadDir(proc + "/fd")
	for _, entry := range entries {
		link, _ := os.Readlink(proc + "/fd/" + entry.Name())
		if sockets[link] {
			return true
		}
	}
	return false
}
