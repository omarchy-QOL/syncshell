package waybar

import (
	"encoding/json"
	"os"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/session"
	"github.com/rivo/uniseg"
)

func ready() session.Snapshot {
	return session.Snapshot{
		Connection: session.Connection{Online: true, Fresh: true, Phase: "ready"},
		Identity:   session.Identity{DeviceID: "LOCAL"},
		Devices:    []session.Device{{ID: "LOCAL", Name: "XPS"}, {ID: "REMOTE", Connected: true}},
		Folders: []session.Folder{{ID: "folder", Label: "private folder", Path: "/private/path",
			Status: session.FolderStatus{State: "idle", GlobalFiles: 145000, GlobalBytes: 22 << 30}}},
		Counts: session.Counts{Folders: 1, Devices: 1, ConnectedDevices: 1},
	}
}

func TestTooltipLayout(t *testing.T) {
	s := ready()
	var p Presenter
	out := p.Render(s, time.Unix(100, 0))
	want := strings.Join([]string{
		"Syncshell · XPS", "",
		"Folders                                    1",
		"Devices                     1 of 1 connected",
		"Tracked                  145k files · 22 GiB", "",
		"Status                            Up to date",
	}, "\n")
	if out.Text != want || out.Tooltip != want || out.Alt != "healthy" {
		t.Fatalf("unexpected layout:\n%s\nwant:\n%s", out.Text, want)
	}
	for _, line := range strings.Split(out.Text, "\n")[2:] {
		if line != "" && uniseg.StringWidth(line) != tooltipColumns {
			t.Errorf("row not aligned: %q", line)
		}
	}
	if strings.Contains(out.Text, "private") {
		t.Fatal("folder identity leaked into tooltip")
	}
	encoded, _ := json.Marshal(out)
	t.Logf("tooltip JSON: %s", encoded)
}

func TestRotationAndIndependentFileLine(t *testing.T) {
	s := ready()
	s.Folders[0].Status.State = "syncing"
	s.Folders = append(s.Folders, session.Folder{ID: "scan", Status: session.FolderStatus{State: "scanning"}})
	s.Activity.Current = &session.Activity{FolderID: "folder", Detail: "report.pdf", Action: "syncing"}
	var p Presenter
	start := time.Unix(100, 0)
	for _, test := range []struct {
		elapsed      time.Duration
		status, dots string
	}{
		{0, "Syncing 1 folder", "   "}, {500 * time.Millisecond, "Syncing 1 folder", ".  "},
		{1500 * time.Millisecond, "Syncing 1 folder", "..."}, {3 * time.Second, "Scanning 1 folder", ".. "},
		{6 * time.Second, "Syncing 1 folder", "   "},
	} {
		out := p.Render(s, start.Add(test.elapsed))
		if test.elapsed == 1500*time.Millisecond {
			encoded, _ := json.Marshal(out)
			t.Logf("tooltip JSON: %s", encoded)
		}
		lines := strings.Split(out.Text, "\n")
		if len(lines) != 8 || !strings.HasSuffix(lines[6], test.status) ||
			!strings.Contains(lines[7], "File syncing"+test.dots+" report.pdf") || out.Alt != "syncing" {
			t.Fatalf("unexpected presentation at %s: %#v", test.elapsed, out)
		}
	}
	// A new high-priority condition is visible immediately, not three seconds later.
	s.Folders[0].Status.PullErrors = 1
	out := p.Render(s, start.Add(7*time.Second))
	if out.Alt != "error" || !strings.Contains(out.Text, "1 folder with errors") || !strings.Contains(out.Text, "report.pdf") {
		t.Fatalf("error priority hid activity or was delayed: %#v", out)
	}
	out = p.Render(s, start.Add(10*time.Second))
	if out.Alt != "error" || !strings.Contains(out.Text, "Syncing 1 folder") {
		t.Fatal("icon rotated with text")
	}
	s.Activity.Current = nil
	out = p.Render(s, start.Add(11*time.Second))
	if strings.Contains(out.Text, "File syncing") {
		t.Fatal("stale activity line retained")
	}
}

func TestTruthfulStates(t *testing.T) {
	for _, test := range []struct {
		name, alt, message string
		change             func(*session.Snapshot)
	}{
		{"offline", "offline", "Syncthing unreachable", func(s *session.Snapshot) { s.Connection.Online = false; s.Connection.Phase = "error" }},
		{"auth", "error", "Authorization failed", func(s *session.Snapshot) {
			s.Connection.Online = false
			s.Connection.Error = &session.Error{Code: "unauthorized", Message: "SECRET"}
		}},
		{"stale", "stale", "Status stale", func(s *session.Snapshot) { s.Connection.Fresh = false }},
		{"paused", "paused", "1 folder paused", func(s *session.Snapshot) { s.Folders[0].Paused = true; s.Folders[0].Status.NeedTotalItems = 4 }},
		{"peer", "disconnected", "1 device disconnected", func(s *session.Snapshot) { s.Devices[1].Connected = false }},
		{"unknown", "unknown", "unknown state", func(s *session.Snapshot) { s.Folders[0].Status.State = "unexpected" }},
		{"empty", "empty", "No folders configured", func(s *session.Snapshot) { s.Folders = nil; s.Counts.Folders = 0 }},
		{"pending", "device-invitations", "1 device invitation", func(s *session.Snapshot) { s.PendingDevices = []session.PendingDevice{{ID: "new"}} }},
		{"incomplete", "incomplete", "Snapshot incomplete", func(s *session.Snapshot) { s.Truncation.Folders = 2 }},
	} {
		t.Run(test.name, func(t *testing.T) {
			s := ready()
			test.change(&s)
			var p Presenter
			out := p.Render(s, time.Unix(100, 0))
			if out.Alt != test.alt || !strings.Contains(out.Text, test.message) || strings.Contains(out.Text, "Up to date") || strings.Contains(out.Text, "SECRET") {
				t.Fatalf("misleading state: %#v", out)
			}
			if (!s.Connection.Online || !s.Connection.Fresh) && !strings.Contains(out.Text, "Unavailable") {
				t.Fatal("old counts shown as live")
			}
		})
	}
}

func TestActivitySafetyAndUnicode(t *testing.T) {
	for _, detail := range []string{"Upload report.pdf", "Removing old.txt", "<b>&\".pdf", strings.Repeat("界", 50) + ".txt", "e\u0301👩‍💻.txt\n\t\x00\u202eEND"} {
		s := ready()
		s.Activity.Current = &session.Activity{FolderID: "folder", Detail: detail}
		var p Presenter
		out := p.Render(s, time.Unix(100, 0))
		lines := strings.Split(out.Text, "\n")
		if len(lines) != 8 || uniseg.StringWidth(lines[7]) != tooltipColumns {
			t.Fatalf("bad activity alignment: %q", out.Text)
		}
		if strings.ContainsAny(out.Text, "\t\x00\u202e") {
			t.Fatal("untrusted controls survived")
		}
		encoded, err := json.Marshal(out)
		if err != nil || strings.Contains(string(encoded), "\n") {
			t.Fatal("invalid JSONL framing")
		}
		s.Connection.Fresh = false
		if strings.Contains(p.Render(s, time.Unix(101, 0)).Text, "File syncing") {
			t.Fatal("stale file activity shown")
		}
	}
	if clip("e\u0301e\u0301e\u0301e\u0301e\u0301", 4) != "e\u0301..." {
		t.Fatal("split a grapheme")
	}
}

func TestConfigurationMatchesOutput(t *testing.T) {
	b, err := os.ReadFile("../../../hosts/waybar/config.jsonc")
	if err != nil {
		t.Fatal(err)
	}
	var config map[string]map[string]any
	if err = json.Unmarshal(b, &config); err != nil {
		t.Fatal(err)
	}
	c := config["custom/syncshell"]
	if c["format"] != "<span font_family='Syncshell Icons'>{icon}</span>" || c["tooltip-format"] != "<span font_family='monospace'>{text}</span>" || c["escape"] != true {
		t.Fatal("plain dynamic text must be escaped inside scoped static markup")
	}
	if c["interval"] != nil || c["signal"] != nil || c["exec-on-event"] != false {
		t.Fatal("not a continuous status module")
	}
	icons := c["format-icons"].(map[string]any)
	for _, state := range []string{"healthy", "starting", "syncing", "scanning", "error", "offline", "stale", "paused", "paused-devices", "disconnected", "unknown", "incomplete", "waiting", "device-invitations", "folder-invitations"} {
		if !slices.Contains([]any{"\ue000", "\ue001", "\ue002"}, icons[state]) {
			t.Errorf("unmapped state: %s", state)
		}
	}
}
