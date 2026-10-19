package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"
)

func TestNativeChild(t *testing.T) {
	if os.Getenv("SYNCSHELL_NATIVE_TEST_CHILD") != "1" {
		return
	}
	for i, arg := range os.Args {
		if arg == "--" {
			if os.Args[i+1] == "native-test-parent" {
				child := nativeCommand(t, append([]string{"native-stream"}, os.Args[i+2:]...)...)
				child.Stdout, child.Stderr = os.Stdout, os.Stderr
				if err := child.Run(); err != nil {
					os.Exit(1)
				}
				os.Exit(0)
			}
			if err := run(context.Background(), os.Args[i+1:], os.Stdin, os.Stdout); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			os.Exit(0)
		}
	}
	os.Exit(2)
}

func nativeCommand(t *testing.T, args ...string) *exec.Cmd {
	t.Helper()
	command := exec.Command(os.Args[0], append([]string{"-test.run=^TestNativeChild$", "--"}, args...)...)
	command.Env = append(os.Environ(), "SYNCSHELL_NATIVE_TEST_CHILD=1")
	return command
}

type nativeChild struct {
	command *exec.Cmd
	reader  *bufio.Scanner
	dir     string
	stderr  bytes.Buffer
}

func startNative(t *testing.T, base, config string, parent ...bool) *nativeChild {
	t.Helper()
	command := "native-stream"
	if len(parent) > 0 {
		command = "native-test-parent"
	}
	child := &nativeChild{command: nativeCommand(t, command, base, "--config", config)}
	pipe, err := child.command.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	child.command.Stderr = &child.stderr
	if err := child.command.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { child.command.Process.Kill(); child.command.Wait() })
	child.reader = bufio.NewScanner(pipe)
	if !child.reader.Scan() {
		t.Fatalf("worker did not become ready: %s", child.stderr.String())
	}
	var ready struct{ Directory string }
	if err := json.Unmarshal(child.reader.Bytes(), &ready); err != nil || ready.Directory == "" {
		t.Fatalf("invalid readiness: %s", child.reader.Text())
	}
	child.dir = ready.Directory
	return child
}

func (c *nativeChild) control(t *testing.T, op string, args ...string) {
	t.Helper()
	command := nativeCommand(t, append([]string{"native-control", c.dir, op}, args...)...)
	if output, err := command.CombinedOutput(); err != nil {
		t.Fatalf("%s: %v: %s", op, err, output)
	}
}

func (c *nativeChild) frame(t *testing.T) map[string]any {
	t.Helper()
	var data strings.Builder
	index := 0
	for c.reader.Scan() {
		var part struct {
			Data, Ack    string
			Index, Count int
		}
		if err := json.Unmarshal(c.reader.Bytes(), &part); err != nil {
			t.Fatal(err)
		}
		index++
		if part.Index != index || part.Count < part.Index {
			t.Fatal("lost or reordered native chunk")
		}
		data.WriteString(part.Data)
		if part.Ack != "" {
			c.control(t, "ack", part.Ack)
		}
		if part.Index == part.Count {
			var frame map[string]any
			if err := json.Unmarshal([]byte(data.String()), &frame); err != nil {
				t.Fatal(err)
			}
			return frame
		}
	}
	t.Fatalf("missing native frame: %v", c.reader.Err())
	return nil
}

func nativeFixture(t *testing.T, large ...bool) string {
	folders := `[]`
	if len(large) > 0 {
		var rows []map[string]any
		for i := 0; i < 64; i++ {
			rows = append(rows, map[string]any{"id": fmt.Sprint(i), "path": "/" + strings.Repeat("a", 2048), "paused": true, "devices": []any{}})
		}
		raw, _ := json.Marshal(rows)
		folders = string(raw)
	}
	t.Helper()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rest/noauth/health" && r.Header.Get("X-API-Key") != commandTestKey {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		responses := map[string]string{
			"/rest/noauth/health": `{"status":"OK"}`, "/rest/system/status": `{"myID":"LOCAL-ID"}`,
			"/rest/system/version": `{"version":"v2.1.3"}`, "/rest/config/devices": `[]`,
			"/rest/config/folders": folders, "/rest/system/connections": `{"connections":{}}`,
			"/rest/cluster/pending/folders": `{}`, "/rest/cluster/pending/devices": `{}`,
			"/rest/system/discovery": `{}`, "/rest/config/gui": `{"theme":"default"}`,
			"/rest/db/status": `{"state":"idle"}`, "/rest/folder/errors": `{"errors":[]}`,
			"/rest/system/paths": `{}`, "/rest/svc/random/string": `{"random":"abcdefghij"}`,
		}
		if response, ok := responses[r.URL.Path]; ok {
			io.WriteString(w, response)
		} else if r.URL.Path == "/rest/events" {
			<-r.Context().Done()
		} else {
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(server.Close)
	config := filepath.Join(t.TempDir(), "config.xml")
	data := fmt.Sprintf(`<configuration><gui><address>%s</address><apikey>%s</apikey></gui></configuration>`, server.URL, commandTestKey)
	if err := os.WriteFile(config, []byte(data), 0o600); err != nil {
		t.Fatal(err)
	}
	return config
}

func TestNativeRealProcessDeliveryShutdownAndRestart(t *testing.T) {
	base, err := os.MkdirTemp("", "ss-native-")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(base)
	config := nativeFixture(t)
	child := startNative(t, base, config)
	if child.frame(t)["type"] != "hello" || child.frame(t)["type"] != "snapshot" {
		t.Fatal("missing startup protocol")
	}
	duplicate := nativeCommand(t, "native-stream", base, "--config", config)
	if err := duplicate.Run(); err == nil {
		t.Fatal("second worker acquired singleton lock")
	}
	child.control(t, "ping")
	for _, request := range []string{
		`{"v":2,"type":"action","id":"suggest","action":"folder.suggest-id","args":{}}`,
		`{"v":2,"type":"shutdown","id":"stop"}`,
	} {
		if err := os.WriteFile(filepath.Join(child.dir, "request-slot.json"), []byte(request), 0o600); err != nil {
			t.Fatal(err)
		}
		child.control(t, "request")
		result := child.frame(t)
		if result["type"] != "result" || result["ok"] != true {
			t.Fatalf("action did not settle: %#v", result)
		}
	}
	if child.frame(t)["type"] != "end" {
		t.Fatal("missing graceful end")
	}
	if err := child.command.Wait(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(child.dir); !os.IsNotExist(err) {
		t.Fatal("generation directory survived shutdown")
	}
	if err := nativeCommand(t, "native-control", child.dir, "ping").Run(); err == nil {
		t.Fatal("retired generation accepted a request")
	}
	next := startNative(t, base, config)
	if next.dir == child.dir {
		t.Fatal("generation reused")
	}
	next.command.Process.Signal(syscall.SIGTERM)
	done := make(chan error, 1)
	go func() { done <- next.command.Wait() }()
	select {
	case <-done:
	case <-time.After(8 * time.Second):
		t.Fatal("worker did not stop while awaiting output acknowledgement")
	}
	if _, err := os.Stat(next.dir); !os.IsNotExist(err) {
		t.Fatal("generation directory survived signal")
	}
}

func TestNativeLargeSnapshotAndCrashRecovery(t *testing.T) {
	base, err := os.MkdirTemp("", "ss-large-")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(base)
	config := nativeFixture(t, true)
	child := startNative(t, base, config)
	child.frame(t)
	frame := child.frame(t)
	state, _ := frame["state"].(map[string]any)
	folders, _ := state["folders"].([]any)
	if len(folders) == 0 {
		t.Fatalf("no folders in snapshot: %#v", frame)
	}
	if len(folders) != 64 || len(folders[63].(map[string]any)["path"].(string)) != 2049 {
		t.Fatal("large snapshot lost folders or bytes")
	}
	raw, _ := json.Marshal(frame)
	if len(raw) <= 64<<10 {
		t.Fatal("fixture does not cross the host line limit")
	}
	if err := child.command.Process.Kill(); err != nil {
		t.Fatal(err)
	}
	child.command.Wait()
	next := startNative(t, base, config)
	if _, err := os.Stat(child.dir); !os.IsNotExist(err) {
		t.Fatal("crashed generation was not removed")
	}
	next.command.Process.Signal(syscall.SIGTERM)
	next.command.Wait()
	if _, err := os.Stat(next.dir); !os.IsNotExist(err) {
		t.Fatal("replacement generation survived exit")
	}
}

func TestNativeWorkerStopsWhenParentDies(t *testing.T) {
	base, err := os.MkdirTemp("", "ss-parent-")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(base)
	child := startNative(t, base, nativeFixture(t), true)
	if err := child.command.Process.Kill(); err != nil {
		t.Fatal(err)
	}
	child.command.Wait()
	deadline := time.Now().Add(8 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(child.dir); os.IsNotExist(err) {
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatal("worker generation survived parent death")
}
