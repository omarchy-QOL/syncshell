package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
	"github.com/omarchy-QOL/syncshell/core/internal/waybar"
)

const testKey = "private-test-api-key"

type fakeAPI struct {
	t            *testing.T
	unauthorized atomic.Bool
	active       atomic.Bool
	inflight     atomic.Int32
	maximum      atomic.Int32
	mu           sync.Mutex
	events       []syncthing.Event
}

func (a *fakeAPI) push(kind, data string) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.events = append(a.events, syncthing.Event{ID: int64(len(a.events) + 1), Type: kind, Data: json.RawMessage(data)})
}

func (a *fakeAPI) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		a.t.Errorf("monitor attempted mutation: %s %s", r.Method, r.URL.Path)
		w.WriteHeader(405)
		return
	}
	if r.URL.Path != "/rest/noauth/health" && (a.unauthorized.Load() || r.Header.Get("X-API-Key") != testKey) {
		http.Error(w, "unauthorized "+testKey, 401)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	switch r.URL.Path {
	case "/rest/noauth/health":
		fmt.Fprint(w, `{"status":"OK"}`)
	case "/rest/system/status":
		fmt.Fprint(w, `{"myID":"LOCAL"}`)
	case "/rest/system/version":
		fmt.Fprint(w, `{"version":"v2.1.3"}`)
	case "/rest/config/devices":
		fmt.Fprint(w, `[{"deviceID":"LOCAL","name":"XPS"},{"deviceID":"REMOTE","name":"Peer"}]`)
	case "/rest/config/folders":
		fmt.Fprint(w, `[{"id":"f1","label":"PRIVATE","path":"/private/path"},{"id":"f2","label":"PRIVATE2","path":"/private/path2"}]`)
	case "/rest/system/connections":
		fmt.Fprint(w, `{"connections":{"REMOTE":{"connected":true}}}`)
	case "/rest/db/status":
		state := "idle"
		if a.active.Load() {
			state = "syncing"
			if r.URL.Query().Get("folder") == "f2" {
				state = "scanning"
			}
		}
		fmt.Fprintf(w, `{"state":%q,"globalFiles":10,"globalBytes":1024}`, state)
	case "/rest/folder/errors":
		fmt.Fprint(w, `{"errors":[]}`)
	case "/rest/db/file":
		fmt.Fprint(w, `{"local":{"type":"DIRECTORY"}}`)
	case "/rest/cluster/pending/folders", "/rest/cluster/pending/devices", "/rest/system/discovery":
		fmt.Fprint(w, `{}`)
	case "/rest/config/gui":
		fmt.Fprint(w, `{"theme":"default"}`)
	case "/rest/system/paths":
		fmt.Fprint(w, `{}`)
	case "/rest/events":
		n := a.inflight.Add(1)
		defer a.inflight.Add(-1)
		for max := a.maximum.Load(); n > max; max = a.maximum.Load() {
			if a.maximum.CompareAndSwap(max, n) {
				break
			}
		}
		if r.URL.Query().Get("timeout") != "0" {
			select {
			case <-r.Context().Done():
				return
			case <-time.After(100 * time.Millisecond):
			}
		}
		since, _ := strconv.ParseInt(r.URL.Query().Get("since"), 10, 64)
		a.mu.Lock()
		defer a.mu.Unlock()
		out := []syncthing.Event{}
		for _, e := range a.events {
			if e.ID > since {
				out = append(out, e)
			}
		}
		if r.URL.Query().Get("limit") == "1" && len(out) > 1 {
			out = out[len(out)-1:]
		}
		json.NewEncoder(w).Encode(out)
	default:
		a.t.Errorf("unexpected API request: %s", r.URL.Path)
		w.WriteHeader(404)
	}
}

type running struct {
	cmd       *exec.Cmd
	lines     chan waybar.Output
	done      chan error
	finished  chan struct{}
	closePipe func() error
}

func start(t *testing.T, binary, config string) *running {
	t.Helper()
	cmd := exec.Command(binary, "status", "--config", config)
	cmd.Env = []string{"PATH=" + t.TempDir()}
	pipe, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err = cmd.Start(); err != nil {
		t.Fatal(err)
	}
	p := &running{cmd: cmd, lines: make(chan waybar.Output, 128), done: make(chan error, 1), finished: make(chan struct{}), closePipe: pipe.Close}
	go func() {
		scanner := bufio.NewScanner(pipe)
		for scanner.Scan() {
			var out waybar.Output
			if err := json.Unmarshal(scanner.Bytes(), &out); err != nil {
				t.Errorf("non-JSON stdout: %s", scanner.Text())
				continue
			}
			if strings.Contains(scanner.Text(), testKey) || strings.Contains(scanner.Text(), "/private/path") || strings.Contains(scanner.Text(), "PRIVATE") {
				t.Error("private target data leaked")
			}
			p.lines <- out
		}
		p.done <- cmd.Wait()
		close(p.finished)
	}()
	t.Cleanup(func() {
		cmd.Process.Kill()
		select {
		case <-p.finished:
		case <-time.After(3 * time.Second):
			t.Error("test subprocess did not stop")
			return
		}
		if strings.Contains(stderr.String(), testKey) {
			t.Error("credential leaked to stderr")
		}
	})
	return p
}

func (p *running) await(t *testing.T, match func(waybar.Output) bool) waybar.Output {
	t.Helper()
	timer := time.NewTimer(8 * time.Second)
	defer timer.Stop()
	for {
		select {
		case out := <-p.lines:
			if match(out) {
				return out
			}
		case err := <-p.done:
			t.Fatalf("producer exited: %v", err)
		case <-timer.C:
			t.Fatal("status did not arrive")
		}
	}
}

func (p *running) stopped(t *testing.T) {
	t.Helper()
	select {
	case err := <-p.done:
		if err != nil {
			t.Fatalf("unclean exit: %v", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("producer did not stop")
	}
}

func TestExecutableSessionLifecycle(t *testing.T) {
	binary := filepath.Join(t.TempDir(), "syncshell-waybar")
	if out, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v %s", err, out)
	}
	api := &fakeAPI{t: t}
	api.unauthorized.Store(true)
	server := httptest.NewServer(api)
	defer server.Close()
	dir := t.TempDir()
	key := filepath.Join(dir, "key")
	config := filepath.Join(dir, "waybar.json")
	if err := os.WriteFile(key, []byte(testKey), 0600); err != nil {
		t.Fatal(err)
	}
	data, _ := json.Marshal(map[string]string{"endpoint": server.URL, "api_key_file": key, "expected_device_id": "LOCAL"})
	if err := os.WriteFile(config, data, 0600); err != nil {
		t.Fatal(err)
	}
	p := start(t, binary, config)
	p.await(t, func(o waybar.Output) bool { return o.Alt == "starting" })
	p.await(t, func(o waybar.Output) bool { return strings.Contains(o.Text, "Authorization failed") })
	api.unauthorized.Store(false)
	p.await(t, func(o waybar.Output) bool { return o.Alt == "healthy" })
	api.unauthorized.Store(true)
	p.await(t, func(o waybar.Output) bool { return o.Alt == "stale" })
	api.unauthorized.Store(false)
	p.await(t, func(o waybar.Output) bool { return o.Alt == "healthy" })
	api.active.Store(true)
	api.push("StateChanged", `{"folder":"f1","to":"syncing"}`)
	api.push("LocalIndexUpdated", `{"folder":"f1","filenames":["directory"]}`)
	api.push("DownloadProgress", `{"f1":{"private-directory/report.pdf":{}}}`)
	p.await(t, func(o waybar.Output) bool {
		return strings.Contains(o.Text, "File syncing") && strings.Contains(o.Text, "report.pdf")
	})
	out := p.await(t, func(o waybar.Output) bool { return strings.Contains(o.Text, "Scanning 1 folder") })
	if out.Alt != "syncing" || !strings.Contains(out.Text, "File syncing") {
		t.Fatal("rotation changed icon or removed file line")
	}
	api.active.Store(false)
	api.push("StateChanged", `{"folder":"f1","to":"idle"}`)
	api.push("ItemFinished", `{"folder":"f1","item":"private-directory/report.pdf"}`)
	out = p.await(t, func(o waybar.Output) bool { return o.Alt == "healthy" })
	if strings.Contains(out.Text, "File syncing") {
		t.Fatal("completed activity remained visible")
	}
	if err := p.cmd.Process.Signal(syscall.SIGTERM); err != nil {
		t.Fatal(err)
	}
	p.stopped(t)
	if api.maximum.Load() > 1 {
		t.Fatal("multiple event cursors")
	}
	// Closing the consumer must stop even when healthy output is coalesced.
	p = start(t, binary, config)
	p.await(t, func(o waybar.Output) bool { return o.Alt == "healthy" })
	if err := p.closePipe(); err != nil {
		t.Fatal(err)
	}
	p.stopped(t)
	// Correcting a missing target file should recover without restarting Waybar.
	missing := filepath.Join(dir, "created-later.json")
	p = start(t, binary, missing)
	p.await(t, func(o waybar.Output) bool { return strings.Contains(o.Text, "Check Waybar configuration") })
	if err := os.WriteFile(missing, data, 0600); err != nil {
		t.Fatal(err)
	}
	p.await(t, func(o waybar.Output) bool { return o.Alt == "healthy" })
	if err := p.cmd.Process.Signal(syscall.SIGTERM); err != nil {
		t.Fatal(err)
	}
	p.stopped(t)
}

func TestOwnerChangeCancels(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	f, err := os.CreateTemp(t.TempDir(), "out")
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	go watchOwner(ctx, cancel, -1, int(f.Fd()))
	select {
	case <-ctx.Done():
	case <-time.After(2 * time.Second):
		t.Fatal("lost owner did not cancel")
	}
}

func TestArgumentsDoNotLeak(t *testing.T) {
	var out bytes.Buffer
	if err := run(context.Background(), []string{"status", "--SECRET"}, &out); err == nil || strings.Contains(err.Error(), "SECRET") {
		t.Fatal("invalid arguments leaked")
	}
	if err := run(context.Background(), []string{"--help"}, &out); err != nil || !strings.Contains(out.String(), "status") {
		t.Fatal("missing help")
	}
}
