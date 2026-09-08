package desktop

import (
	"context"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
	"golang.org/x/sys/unix"
)

var conflictMarker = regexp.MustCompile(`^(.*)\.sync-conflict-[0-9]{8}-[0-9]{6}-[A-Z2-7]{7}(\..*)?$`)

func original(path string) string {
	match := conflictMarker.FindStringSubmatch(filepath.Base(path))
	if match == nil {
		return ""
	}
	name := match[1] + match[2]
	if name == "" || conflictMarker.MatchString(name) {
		return ""
	}
	return filepath.Join(filepath.Dir(path), name)
}

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
			if parseErr == nil && int(value) == port && listenerAddress(address, endpoint.Hostname()) {
				sockets["socket:["+fields[9]+"]"] = true
			}
		}
	}
	matches := func(pid int) bool {
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
			peer, e1 := os.Readlink(proc + "/ns/" + namespace)
			self, e2 := os.Readlink("/proc/self/ns/" + namespace)
			if e1 != nil || e2 != nil || peer != self {
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
	if b.pid > 0 && matches(b.pid) {
		return nil
	}
	entries, _ := os.ReadDir("/proc")
	for _, entry := range entries {
		pid, err := strconv.Atoi(entry.Name())
		if err == nil && matches(pid) {
			b.pid = pid
			return nil
		}
	}
	b.pid = 0
	return errors.New("file actions require Syncthing on this desktop, under the same user and outside containers or tunnels")
}

func (b *Bridge) action(ctx context.Context, action string, body request) (any, error) {
	if action != "status" && action != "check" && action != "open" && action != "rename" {
		return nil, errors.New("unsupported desktop action")
	}
	status, err := b.client.Status(ctx)
	if err != nil {
		return nil, err
	}
	if body.Device == "" || body.Device != status.MyID {
		return nil, errors.New("Syncthing identity changed; reopen the Web UI from the plugin")
	}
	if err := b.localProcess(); err != nil {
		return nil, err
	}
	paths, err := b.client.SystemPaths(ctx)
	if err != nil {
		return nil, err
	}
	selected, e1 := filepath.EvalSymlinks(b.client.Target().ConfigPath)
	reported, e2 := filepath.EvalSymlinks(paths.Config)
	if e1 != nil || e2 != nil || selected != reported {
		return nil, errors.New("local Syncthing configuration could not be verified")
	}
	if action == "status" {
		return map[string]bool{"available": true}, nil
	}
	folder, err := b.client.Folder(ctx, body.Folder)
	if err != nil {
		return nil, err
	}
	return b.fileAction(ctx, action, body, folder, status.Tilde)
}

func (b *Bridge) fileAction(ctx context.Context, action string, body request, folder syncthing.Folder, home string) (any, error) {
	if folder.Path != body.Root {
		return nil, errors.New("folder path changed; recheck the file list")
	}
	root := folder.Path
	if root == "~" || strings.HasPrefix(root, "~/") {
		root = filepath.Join(home, strings.TrimPrefix(root, "~"))
	}
	if !filepath.IsAbs(root) {
		return nil, errors.New("desktop actions require an absolute Syncthing folder path")
	}
	if !filepath.IsLocal(body.Path) || !filepath.IsLocal(body.File) || strings.ContainsRune(body.File, 0) || strings.ContainsRune(body.Path, 0) ||
		(body.File != body.Path && original(body.File) != body.Path) {
		return nil, errors.New("file is not part of the selected conflict")
	}
	fd, err := directory(root, filepath.Dir(body.File))
	if err != nil {
		return nil, fmt.Errorf("folder is unavailable to this desktop: %w", err)
	}
	defer unix.Close(fd)
	var file unix.Stat_t
	if err := unix.Fstatat(fd, filepath.Base(body.File), &file, unix.AT_SYMLINK_NOFOLLOW); err != nil {
		return nil, errors.New("file is no longer available locally; recheck the list")
	}
	if file.Mode&unix.S_IFMT != unix.S_IFREG {
		return nil, errors.New("desktop actions require a regular file, without symlinks")
	}
	if action == "check" {
		writeErr := unix.Faccessat(fd, ".", unix.W_OK|unix.X_OK, unix.AT_EACCESS)
		reason := ""
		if writeErr != nil {
			reason = "This desktop user cannot rename files in this folder."
		}
		return map[string]any{"open": true, "rename": writeErr == nil, "reason": reason}, nil
	}
	if action == "open" {
		return map[string]bool{"opened": true}, b.launch(ctx, filepath.Join(root, filepath.Dir(body.File)))
	}
	if original(body.File) != body.Path {
		return nil, errors.New("only a Syncthing conflict filename can be restored")
	}
	if file.Size != body.Size || file.Mtim.Sec != body.Modified.Unix() || file.Mtim.Nsec != int64(body.Modified.Nanosecond()) {
		return nil, errors.New("the conflict file changed; recheck before renaming")
	}
	// The directory descriptor and no-replace rename prevent path redirection and replacement.
	if err := unix.Renameat2(fd, filepath.Base(body.File), fd, filepath.Base(body.Path), unix.RENAME_NOREPLACE); err != nil {
		if errors.Is(err, unix.EEXIST) {
			return nil, errors.New("the original name already exists; no file was replaced")
		}
		return nil, fmt.Errorf("could not rename the conflict file: %w", err)
	}
	return map[string]bool{"renamed": true}, nil
}

// Do not follow a folder or intermediate symlink into unrelated files.
func directory(root, relative string) (int, error) {
	fd, err := unix.Open("/", unix.O_RDONLY|unix.O_DIRECTORY|unix.O_CLOEXEC, 0)
	if err != nil {
		return -1, err
	}
	for _, part := range strings.Split(filepath.Join(root, relative), "/") {
		if part == "" || part == "." {
			continue
		}
		next, err := unix.Openat(fd, part, unix.O_RDONLY|unix.O_DIRECTORY|unix.O_NOFOLLOW|unix.O_CLOEXEC, 0)
		unix.Close(fd)
		if err != nil {
			return -1, err
		}
		fd = next
	}
	return fd, nil
}
