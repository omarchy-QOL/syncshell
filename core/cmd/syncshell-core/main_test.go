package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

const commandTestKey = "command-test-key"

func TestRunProbeAndStatus(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rest/noauth/health" &&
			r.Header.Get("X-API-Key") != commandTestKey {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		responses := map[string]string{
			"/rest/noauth/health":           `{"status":"OK"}`,
			"/rest/system/status":           `{"myID":"LOCAL-ID"}`,
			"/rest/system/version":          `{"version":"v2.1.3"}`,
			"/rest/config/devices":          `[{"deviceID":"LOCAL-ID","name":"local"}]`,
			"/rest/config/folders":          `[]`,
			"/rest/system/connections":      `{"connections":{}}`,
			"/rest/cluster/pending/folders": `{}`,
			"/rest/cluster/pending/devices": `{}`,
			"/rest/system/discovery":        `{}`,
			"/rest/config/gui":              `{"theme":"default"}`,
			"/rest/system/paths":            `{"guiAssets":"/tmp/gui"}`,
		}
		response, ok := responses[r.URL.Path]
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, response)
	}))
	defer server.Close()
	config := filepath.Join(t.TempDir(), "config.xml")
	contents := fmt.Sprintf(`<configuration><gui><address>%s</address>`+
		`<apikey>%s</apikey></gui></configuration>`, server.URL, commandTestKey)
	if err := os.WriteFile(config, []byte(contents), 0o600); err != nil {
		t.Fatal(err)
	}

	for _, command := range []string{"probe", "status"} {
		t.Run(command, func(t *testing.T) {
			var output bytes.Buffer
			err := run(context.Background(),
				[]string{command, "--config", config, "--json"},
				bytes.NewReader(nil), &output)
			if err != nil {
				t.Fatal(err)
			}
			var result map[string]any
			if err := json.Unmarshal(output.Bytes(), &result); err != nil {
				t.Fatalf("invalid JSON output: %v\n%s", err, output.Bytes())
			}
			state := result
			if command == "status" {
				state, _ = result["state"].(map[string]any)
			}
			connection, ok := state["connection"].(map[string]any)
			if !ok || connection["phase"] != "ready" {
				t.Fatalf("unexpected %s output: %#v", command, result)
			}
		})
	}
}

func TestRunRejectsInvalidInvocation(t *testing.T) {
	for _, args := range [][]string{
		nil,
		{"unknown"},
		{"probe"},
		{"status"},
	} {
		if err := run(context.Background(), args, bytes.NewReader(nil), io.Discard); err == nil {
			t.Fatalf("run accepted arguments %q", args)
		}
	}
}

func TestParseOptionsRequiresExplicitLifecycleAuthority(t *testing.T) {
	flags := flag.NewFlagSet("test", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	_, _, err := parseOptions(flags, []string{
		"--lifecycle-kind", "systemd-user",
		"--lifecycle-unit", "syncthing.service",
	})
	if err == nil {
		t.Fatal("unauthorized lifecycle binding succeeded")
	}
}

func TestParseOptionsAcceptsBoundedOperationalValues(t *testing.T) {
	flags := flag.NewFlagSet("test", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	config, outputJSON, err := parseOptions(flags, []string{
		"--probe-interval-seconds", "2",
		"--desired-service-state", "disabled",
		"--lifecycle-kind", "systemd-user",
		"--lifecycle-authorized",
		"--lifecycle-unit", "syncthing.service",
		"--json",
	})
	if err != nil {
		t.Fatal(err)
	}
	if config.ProbeInterval.Seconds() != 2 ||
		config.DesiredServiceState != "disabled" || !config.Lifecycle.Authorized ||
		!outputJSON {
		t.Fatalf("unexpected config: %#v", config)
	}
}

func TestParseOptionsRejectsInvalidValues(t *testing.T) {
	tests := [][]string{
		{"--unknown"},
		{"extra"},
		{"--lifecycle-kind", "other"},
		{"--lifecycle-authorized", "--lifecycle-kind", "systemd-user"},
		{"--probe-interval-seconds", "0"},
		{"--desired-service-state", "other"},
		{"--lifecycle-kind", "systemd-user", "--lifecycle-authorized",
			"--lifecycle-unit", "bad\nunit"},
	}
	for _, args := range tests {
		flags := flag.NewFlagSet("test", flag.ContinueOnError)
		flags.SetOutput(io.Discard)
		if _, _, err := parseOptions(flags, args); err == nil {
			t.Errorf("parseOptions accepted %q", args)
		}
	}
}
