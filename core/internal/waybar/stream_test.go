package waybar

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/session"
)

type capture chan Output

func (c capture) Write(b []byte) (int, error) {
	var out Output
	if err := json.Unmarshal(b, &out); err != nil {
		return 0, err
	}
	c <- out
	return len(b), nil
}

func take(t *testing.T, c <-chan Output) Output {
	t.Helper()
	select {
	case out := <-c:
		return out
	case <-time.After(time.Second):
		t.Fatal("no JSON output")
		return Output{}
	}
}

func TestStreamCoalescesAndCancels(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	updates := make(chan session.Snapshot, 4)
	ticks := make(chan time.Time, 4)
	output := make(capture, 16)
	done := make(chan error, 1)
	go func() { done <- stream(ctx, updates, ticks, output) }()
	if take(t, output).Alt != "starting" {
		t.Fatal("missing immediate startup state")
	}
	updates <- ready()
	if take(t, output).Alt != "healthy" {
		t.Fatal("missing session update")
	}
	updates <- ready()
	ticks <- time.Now().Add(3 * time.Second)
	select {
	case out := <-output:
		t.Fatalf("unchanged output emitted: %#v", out)
	case <-time.After(20 * time.Millisecond):
	}
	cancel()
	select {
	case err := <-done:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(time.Second):
		t.Fatal("stream did not cancel")
	}
}

type failedWriter struct{}

func (failedWriter) Write([]byte) (int, error) { return 0, io.ErrClosedPipe }

func TestRunClosedOutputStopsDiscovery(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	err := Run(ctx, filepath.Join(t.TempDir(), "missing.json"), failedWriter{})
	if !errors.Is(err, io.ErrClosedPipe) || ctx.Err() != nil {
		t.Fatalf("closed output did not stop observer: %v", err)
	}
}

func TestConfigValidation(t *testing.T) {
	for _, body := range []string{
		`{"api_key":"SECRET"}`, `{} {}`, `null`, `null null`, `{"endpoint":1}`,
		`{"syncthing_config":"relative.xml"}`, `{"api_key_file":"/key"}`,
		`{"syncthing_config":"/config","endpoint":"http://example"}`,
	} {
		path := filepath.Join(t.TempDir(), "waybar.json")
		if err := os.WriteFile(path, []byte(body), 0600); err != nil {
			t.Fatal(err)
		}
		if _, err := loadConfig(path); err == nil || strings.Contains(err.Error(), "SECRET") {
			t.Fatalf("invalid or leaking config: %q %v", body, err)
		}
	}
	path := filepath.Join(t.TempDir(), "waybar.json")
	body := `{"endpoint":"https://example:8384","api_key_file":"/key","tls_certificate":"/cert","expected_device_id":"DEVICE"}`
	if err := os.WriteFile(path, []byte(body), 0600); err != nil {
		t.Fatal(err)
	}
	c, err := loadConfig(path)
	if err != nil || !c.ReadOnly || c.Discovery.TLSCertificate != "/cert" || c.Discovery.ExpectedDeviceID != "DEVICE" || c.Lifecycle.Authorized {
		t.Fatalf("target selection changed: %#v %v", c, err)
	}
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	if _, err := loadConfig(""); err != nil {
		t.Fatalf("missing optional file blocked discovery: %v", err)
	}
}
