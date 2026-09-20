package session

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
	"github.com/omarchy-QOL/syncshell/core/internal/systemduser"
)

func TestLifecycleActionsRequireAndRetainTargetAuthority(t *testing.T) {
	directory := t.TempDir()
	activeFile := filepath.Join(directory, "active")
	enabledFile := filepath.Join(directory, "enabled")
	callsFile := filepath.Join(directory, "calls")
	writeState(t, activeFile, "inactive")
	writeState(t, enabledFile, "disabled")
	writeState(t, callsFile, "0")

	server := httptest.NewServer(lifecycleAPI{activeFile: activeFile})
	defer server.Close()
	configPath := filepath.Join(directory, "config.xml")
	config := fmt.Sprintf(`<configuration><gui tls="false"><address>%s</address><apikey>%s</apikey></gui></configuration>`,
		strings.TrimPrefix(server.URL, "http://"), sessionTestKey)
	if err := os.WriteFile(configPath, []byte(config), 0o600); err != nil {
		t.Fatal(err)
	}
	command := lifecycleSystemctl(t, directory, configPath, activeFile, enabledFile,
		callsFile)
	coreSession, err := New(context.Background(), Config{
		Discovery: syncthing.DiscoveryOptions{ConfigPath: configPath},
		Lifecycle: systemduser.Binding{Authorized: true, Unit: "syncthing.service",
			ConfigPath: configPath},
		SystemdCommand: command,
	})
	if err != nil {
		t.Fatal(err)
	}
	published, err := coreSession.Refresh(context.Background())
	if err == nil || !published.State.Lifecycle.CanStart {
		t.Fatalf("offline candidate lacks start authority: %#v %v", published.State, err)
	}

	for index, action := range []string{"start", "enable", "disable", "stop"} {
		result := coreSession.Act(context.Background(), "lifecycle."+action,
			ActionArguments{})
		if !result.OK {
			t.Fatalf("lifecycle %s failed: %#v", action, result)
		}
		if calls := readState(t, callsFile); calls != fmt.Sprint(index+1) {
			t.Fatalf("lifecycle %s command count is %s", action, calls)
		}
	}
	if state := readState(t, activeFile); state != "inactive" {
		t.Fatalf("service state is %s", state)
	}
	if state := readState(t, enabledFile); state != "disabled" {
		t.Fatalf("unit-file state is %s", state)
	}
	writeState(t, activeFile, "active")
	beforeAlreadyReached := readState(t, callsFile)
	if result := coreSession.Act(context.Background(), "lifecycle.start",
		ActionArguments{}); !result.OK {
		t.Fatalf("already reached lifecycle state failed: %#v", result)
	}
	if calls := readState(t, callsFile); calls != beforeAlreadyReached {
		t.Fatalf("already reached lifecycle state invoked command: %s -> %s",
			beforeAlreadyReached, calls)
	}

	script, err := os.ReadFile(command)
	if err != nil {
		t.Fatal(err)
	}
	immediateStop := fmt.Sprintf("stop) printf 'inactive\\n' >%q ;;", activeFile)
	delayedStop := fmt.Sprintf("stop) (sleep 0.3; printf 'inactive\\n' >%q) "+
		">/dev/null 2>&1 & ;;", activeFile)
	script = []byte(strings.Replace(string(script), immediateStop, delayedStop, 1))
	if err := os.WriteFile(command, script, 0o700); err != nil {
		t.Fatal(err)
	}
	started := time.Now()
	if result := coreSession.Act(context.Background(), "lifecycle.stop",
		ActionArguments{}); !result.OK {
		t.Fatalf("delayed lifecycle action failed: %#v", result)
	}
	if time.Since(started) < 200*time.Millisecond {
		t.Fatal("delayed lifecycle action was not observed through polling")
	}
	if calls := readState(t, callsFile); calls != "5" {
		t.Fatalf("delayed lifecycle command count is %s", calls)
	}

	script, err = os.ReadFile(command)
	if err != nil {
		t.Fatal(err)
	}
	script = []byte(strings.Replace(string(script), delayedStop, "stop) : ;;", 1))
	if err := os.WriteFile(command, script, 0o700); err != nil {
		t.Fatal(err)
	}
	writeState(t, activeFile, "active")
	timedOut := coreSession.Act(context.Background(), "lifecycle.stop",
		ActionArguments{})
	if timedOut.OK || timedOut.Error == nil ||
		timedOut.Error.Code != "lifecycle_timeout" {
		t.Fatalf("lifecycle timeout was not returned: %#v", timedOut)
	}
	if calls := readState(t, callsFile); calls != "6" {
		t.Fatalf("timed-out lifecycle command count is %s", calls)
	}

	script, err = os.ReadFile(command)
	if err != nil {
		t.Fatal(err)
	}
	script = []byte(strings.Replace(string(script), "active=$(<",
		"[[ ${2:-} == show ]] || exit 1\nactive=$(<", 1))
	if err := os.WriteFile(command, script, 0o700); err != nil {
		t.Fatal(err)
	}
	for index, test := range []struct{ action, active, enabled string }{
		{"start", "inactive", "disabled"},
		{"stop", "active", "disabled"},
		{"enable", "active", "disabled"},
		{"disable", "active", "enabled"},
	} {
		t.Run("rejected "+test.action, func(t *testing.T) {
			writeState(t, activeFile, test.active)
			writeState(t, enabledFile, test.enabled)
			failed := coreSession.Act(context.Background(), "lifecycle."+test.action,
				ActionArguments{})
			if failed.OK || failed.Error == nil || failed.Error.Code != "lifecycle_failed" {
				t.Fatalf("service rejection was not returned: %#v", failed)
			}
			if calls := readState(t, callsFile); calls != fmt.Sprint(7+index) {
				t.Fatalf("failed lifecycle command count is %s", calls)
			}
			if readState(t, activeFile) != test.active || readState(t, enabledFile) != test.enabled {
				t.Fatal("rejected action changed service state")
			}
		})
	}

	external, err := New(context.Background(), Config{
		Discovery: syncthing.DiscoveryOptions{ConfigPath: configPath},
	})
	if err != nil {
		t.Fatal(err)
	}
	result := external.Act(context.Background(), "lifecycle.start",
		ActionArguments{})
	if result.OK || result.Error == nil || result.Error.Code != "lifecycle_forbidden" {
		t.Fatalf("external target gained lifecycle authority: %#v", result)
	}
	if calls := readState(t, callsFile); calls != "10" {
		t.Fatalf("authority rejection invoked lifecycle command: %s", calls)
	}
}

type lifecycleAPI struct{ activeFile string }

func (a lifecycleAPI) ServeHTTP(writer http.ResponseWriter, request *http.Request) {
	active, _ := os.ReadFile(a.activeFile)
	if strings.TrimSpace(string(active)) != "active" {
		http.Error(writer, "offline", http.StatusServiceUnavailable)
		return
	}
	switch request.URL.Path {
	case "/rest/noauth/health":
		writeSessionJSON(writer, `{"status":"OK"}`)
	case "/rest/system/status":
		writeSessionJSON(writer, `{"myID":"LOCAL"}`)
	case "/rest/system/version":
		writeSessionJSON(writer, `{"version":"v2.1.3"}`)
	case "/rest/config/devices", "/rest/config/folders":
		writeSessionJSON(writer, `[]`)
	case "/rest/system/connections":
		writeSessionJSON(writer, `{"connections":{}}`)
	case "/rest/cluster/pending/folders", "/rest/cluster/pending/devices",
		"/rest/system/discovery":
		writeSessionJSON(writer, `{}`)
	case "/rest/config/gui":
		writeSessionJSON(writer, `{"theme":"default"}`)
	case "/rest/system/paths":
		writeSessionJSON(writer, `{"guiAssets":"/tmp/gui"}`)
	default:
		http.NotFound(writer, request)
	}
}

func lifecycleSystemctl(
	t *testing.T,
	directory string,
	configPath string,
	activeFile string,
	enabledFile string,
	callsFile string,
) string {
	t.Helper()
	command := filepath.Join(directory, "systemctl")
	script := fmt.Sprintf(`#!/bin/bash
set -euo pipefail
if [[ ${2:-} != show ]]; then
  calls=$(<%q)
  printf '%%s\n' "$((calls + 1))" >%q
fi
active=$(<%q)
enabled=$(<%q)
case "${2:-}" in
  show)
    printf '%%s\n' 'LoadState=loaded' "ActiveState=$active" \
      "UnitFileState=$enabled" \
      'FragmentPath=/usr/lib/systemd/user/syncthing.service' \
      'ExecStart=/usr/bin/syncthing serve --config=%s --data=%s' 'Environment='
    ;;
  start) printf 'active\n' >%q ;;
  stop) printf 'inactive\n' >%q ;;
  enable) printf 'enabled\n' >%q ;;
  disable) printf 'disabled\n' >%q ;;
  *) exit 2 ;;
esac
`, callsFile, callsFile, activeFile, enabledFile,
		filepath.Dir(configPath), filepath.Dir(configPath),
		activeFile, activeFile, enabledFile, enabledFile)
	if err := os.WriteFile(command, []byte(script), 0o700); err != nil {
		t.Fatal(err)
	}
	return command
}

func writeState(t *testing.T, path, value string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(value+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
}

func readState(t *testing.T, path string) string {
	t.Helper()
	contents, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return strings.TrimSpace(string(contents))
}
