package desktop

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
)

func TestBridgeOpenUsesPrivateLaunchPage(t *testing.T) {
	t.Setenv("DBUS_SESSION_BUS_ADDRESS", "unix:path=/test/session-bus")
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	client, err := syncthing.NewClient(syncthing.Target{
		Endpoint: "http://127.0.0.1:8384",
		Local:    true,
	})
	if err != nil {
		t.Fatal(err)
	}
	bridge, err := New(client)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(bridge.Close)

	var launched string
	bridge.launch = func(_ context.Context, target string) error {
		launched = target
		return nil
	}
	if err := bridge.Open(context.Background()); err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(launched, "file://") {
		t.Fatalf("opened %q, want a private file URL", launched)
	}
	page, err := os.ReadFile(filepath.Join(bridge.launchDir, "open.html"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(page), bridge.address+"/"+bridge.token) ||
		!strings.Contains(string(page), "http://127.0.0.1:8384") {
		t.Fatalf("launch page does not contain the scoped grant: %s", page)
	}
	info, err := os.Stat(filepath.Join(bridge.launchDir, "open.html"))
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("launch page mode = %v, want 0600", info.Mode().Perm())
	}

	directory := bridge.launchDir
	bridge.Close()
	if _, err := os.Stat(directory); !os.IsNotExist(err) {
		t.Fatalf("private launch directory remains after close: %v", err)
	}
}

func TestBridgeRequiresLocalDesktopSession(t *testing.T) {
	client, err := syncthing.NewClient(syncthing.Target{
		Endpoint: "http://127.0.0.1:8384",
		Local:    true,
	})
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("DBUS_SESSION_BUS_ADDRESS", "")
	if _, err := New(client); err == nil {
		t.Fatal("bridge accepted a session without a desktop bus")
	}

	remote, err := syncthing.NewClient(syncthing.Target{
		Endpoint: "https://syncthing.example",
	})
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("DBUS_SESSION_BUS_ADDRESS", "unix:path=/test/session-bus")
	if _, err := New(remote); err == nil {
		t.Fatal("bridge accepted a remote Syncthing target")
	}
}

func TestBridgeRejectsLookalikeLocalProcess(t *testing.T) {
	api := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rest/system/status" {
			http.NotFound(w, r)
			return
		}
		_, _ = io.WriteString(w, `{"myID":"LOCAL-ID"}`)
	}))
	defer api.Close()
	client, err := syncthing.NewClient(syncthing.Target{
		Endpoint: api.URL,
		Local:    true,
	})
	if err != nil {
		t.Fatal(err)
	}
	bridge := &Bridge{
		address: "127.0.0.1:12345",
		origin:  api.URL,
		token:   strings.Repeat("a", 64),
		client:  client,
	}
	r := httptest.NewRequest(http.MethodPost,
		"http://"+bridge.address+"/status", strings.NewReader(`{"device":"LOCAL-ID"}`))
	r.Header.Set("Origin", bridge.origin)
	r.Header.Set("X-Syncshell-Token", bridge.token)
	w := httptest.NewRecorder()
	bridge.ServeHTTP(w, r)
	if w.Code != http.StatusConflict ||
		!strings.Contains(w.Body.String(), "file actions require Syncthing") {
		t.Fatalf("lookalike process response = %d %s", w.Code, w.Body.String())
	}
}

func TestDesktopRequestBoundary(t *testing.T) {
	b := &Bridge{address: "127.0.0.1:12345", origin: "http://127.0.0.1:8384", token: strings.Repeat("a", 64)}
	for _, scenario := range []string{"origin", "host", "token", "get", "oversized", "unknown-field", "trailing", "preflight"} {
		t.Run(scenario, func(t *testing.T) {
			body := "{}"
			method := http.MethodPost
			if scenario == "oversized" {
				body = strings.Repeat("x", 17000)
			}
			if scenario == "unknown-field" {
				body = `{"command":"rm"}`
			}
			if scenario == "trailing" {
				body = "{} {}"
			}
			if scenario == "get" {
				method = http.MethodGet
			}
			if scenario == "preflight" {
				method = http.MethodOptions
			}
			r := httptest.NewRequest(method, "http://"+b.address+"/rename", strings.NewReader(body))
			r.Header.Set("Origin", b.origin)
			r.Header.Set("X-Syncshell-Token", b.token)
			if scenario == "origin" {
				r.Header.Set("Origin", "https://unrelated.example")
			}
			if scenario == "host" {
				r.Host = "attacker.example"
			}
			if scenario == "token" {
				r.Header.Del("X-Syncshell-Token")
			}
			w := httptest.NewRecorder()
			b.ServeHTTP(w, r)
			want := http.StatusForbidden
			if scenario == "oversized" || scenario == "unknown-field" || scenario == "trailing" {
				want = http.StatusBadRequest
			}
			if scenario == "preflight" {
				want = http.StatusNoContent
			}
			if w.Code != want {
				t.Fatalf("status %d, want %d", w.Code, want)
			}
		})
	}
}
