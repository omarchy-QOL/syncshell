// Package waybar presents the shared session through Waybar's JSON interface.
package waybar

import (
	"fmt"
	"slices"
	"strings"
	"time"
	"unicode"

	"github.com/omarchy-QOL/syncshell/core/internal/session"
	"github.com/rivo/uniseg"
)

const (
	statusInterval = 3 * time.Second
	dotInterval    = 500 * time.Millisecond
	tooltipColumns = 44
)

// Output carries plain text; the host's trusted format supplies Pango markup.
type Output struct {
	Text    string   `json:"text"`
	Tooltip string   `json:"tooltip"`
	Alt     string   `json:"alt"`
	Class   []string `json:"class"`
}

type condition struct{ class, text string }

// Presenter keeps rotation independent of event frequency and icon priority.
type Presenter struct {
	classes []string
	index   int
	next    time.Time
	started time.Time
}

func (p *Presenter) Render(s session.Snapshot, now time.Time) Output {
	conditions, activity := summarize(s)
	classes := make([]string, len(conditions))
	for i, c := range conditions {
		classes[i] = c.class
	}
	if !slices.Equal(classes, p.classes) {
		p.classes, p.index, p.next = classes, 0, now.Add(statusInterval)
	} else if !now.Before(p.next) {
		steps := int(now.Sub(p.next)/statusInterval) + 1
		p.index = (p.index + steps) % len(conditions)
		p.next = p.next.Add(time.Duration(steps) * statusInterval)
	}
	name := "Syncthing"
	for _, d := range s.Devices {
		if d.ID == s.Identity.DeviceID && d.Name != "" {
			name = d.Name
			break
		}
	}
	folders, devices, tracked := "Unavailable", "Unavailable", "Unavailable"
	if s.Connection.Online && s.Connection.Fresh {
		folders = fmt.Sprint(s.Counts.Folders)
		devices = fmt.Sprintf("%d of %d connected", s.Counts.ConnectedDevices, s.Counts.Devices)
		var files, bytes int64
		for _, f := range s.Folders {
			files += int64(max(0, f.Status.GlobalFiles))
			bytes += max(0, f.Status.GlobalBytes)
		}
		tracked = formatCount(files) + " files · " + formatBytes(bytes)
		if s.Truncation.Folders > 0 {
			folders += "+"
			tracked += "+"
		}
		if s.Truncation.Devices > 0 {
			devices += "+"
		}
	}
	lines := []string{clip("Syncshell · "+clean(name), tooltipColumns), "",
		row("Folders", folders), row("Devices", devices), row("Tracked", tracked), "",
		row("Status", conditions[p.index].text)}
	if activity != "" {
		if p.started.IsZero() {
			p.started = now
		}
		dots := strings.Repeat(".", int(max(0, now.Sub(p.started))/dotInterval)%4)
		// Reserve all three dot positions so the filename does not wobble.
		line := fmt.Sprintf("File syncing%-3s %s", dots, clip(clean(activity), tooltipColumns-16))
		lines = append(lines, strings.Repeat(" ", max(0, tooltipColumns-uniseg.StringWidth(line)))+line)
	} else {
		p.started = time.Time{}
	}
	text := strings.Join(lines, "\n")
	return Output{Text: text, Tooltip: text, Alt: classes[0], Class: classes}
}

func summarize(s session.Snapshot) ([]condition, string) {
	c := s.Connection
	if c.Error != nil {
		return []condition{{"error", errorText(c.Error.Code)}}, ""
	}
	if !c.Online {
		switch c.Phase {
		case "", "discovering":
			return []condition{{"starting", "Finding Syncthing"}}, ""
		case "loading":
			return []condition{{"starting", "Reading status"}}, ""
		default:
			return []condition{{"offline", "Syncthing unreachable"}}, ""
		}
	}
	if !c.Fresh {
		return []condition{{"stale", "Status stale"}}, ""
	}
	var result []condition
	add := func(class, message string) { result = append(result, condition{class, message}) }
	active := make(map[string]bool)
	for _, a := range s.Activity.Files {
		active[a.FolderID] = true
	}
	if s.Activity.Current != nil {
		active[s.Activity.Current.FolderID] = true
	}
	problems, syncing, scanning, paused, waiting, unknown := 0, 0, 0, 0, 0, 0
	activity := ""
	for _, f := range s.Folders {
		state := f.Status
		if state.State == "error" || state.Error != "" || state.PullErrors > 0 || len(state.Errors) > 0 {
			problems++
		}
		if f.Paused {
			paused++
			continue
		}
		if active[f.ID] || state.State == "syncing" || state.NeedTotalItems > 0 {
			syncing++
		}
		if strings.HasPrefix(state.State, "scan") {
			scanning++
		}
		if state.State == "sync-wait" || state.State == "sync-preparing" || state.State == "cleaning" {
			waiting++
		}
		switch state.State {
		case "idle", "syncing", "sync-wait", "sync-preparing", "cleaning", "error":
		default:
			if !strings.HasPrefix(state.State, "scan") {
				unknown++
			}
		}
		if a := s.Activity.Current; a != nil && a.FolderID == f.ID {
			activity = a.Detail
		}
	}
	if problems > 0 {
		add("error", numbered(problems, "folder", "folders")+" with errors")
	}
	if syncing > 0 {
		add("syncing", "Syncing "+numbered(syncing, "folder", "folders"))
	}
	if scanning > 0 {
		add("scanning", "Scanning "+numbered(scanning, "folder", "folders"))
	}
	if paused > 0 {
		add("paused", numbered(paused, "folder", "folders")+" paused")
	}
	if waiting > 0 {
		add("waiting", numbered(waiting, "folder", "folders")+" preparing or waiting")
	}
	if unknown > 0 {
		add("unknown", numbered(unknown, "folder", "folders")+" with unknown state")
	}
	disconnected, pausedDevices := 0, 0
	for _, d := range s.Devices {
		if d.ID == s.Identity.DeviceID {
			continue
		}
		if d.Paused {
			pausedDevices++
		} else if !d.Connected {
			disconnected++
		}
	}
	if pausedDevices > 0 {
		add("paused-devices", numbered(pausedDevices, "device", "devices")+" paused")
	}
	if disconnected > 0 {
		add("disconnected", numbered(disconnected, "device", "devices")+" disconnected")
	}
	if n := len(s.PendingDevices); n > 0 {
		add("device-invitations", numbered(n, "device invitation", "device invitations"))
	}
	if n := len(s.PendingFolders); n > 0 {
		add("folder-invitations", numbered(n, "folder share invitation", "folder share invitations"))
	}
	if s.Truncation != (session.Truncation{}) {
		add("incomplete", "Snapshot incomplete")
	}
	if len(result) == 0 {
		if len(s.Folders) == 0 {
			add("empty", "No folders configured")
		} else {
			add("healthy", "Up to date")
		}
	}
	return result, activity
}

func errorText(code string) string {
	switch code {
	case "waybar-config":
		return "Check Waybar configuration"
	case "unauthorized":
		return "Authorization failed"
	case "credential":
		return "Check API credential file"
	case "config":
		return "Check Syncthing configuration"
	case "ambiguity":
		return "Select a Syncthing configuration"
	case "identity":
		return "Syncthing identity mismatch"
	case "tls":
		return "TLS verification failed"
	case "schema", "http":
		return "Syncthing API error"
	default:
		return "Syncthing unreachable"
	}
}

func numbered(n int, singular, plural string) string {
	if n == 1 {
		return "1 " + singular
	}
	return fmt.Sprintf("%d %s", n, plural)
}

func clean(value string) string {
	return strings.TrimSpace(strings.Map(func(r rune) rune {
		if unicode.IsControl(r) || (unicode.Is(unicode.Cf, r) && r != '\u200c' && r != '\u200d') || r == '\u2028' || r == '\u2029' {
			return ' '
		}
		return r
	}, strings.ToValidUTF8(value, "�")))
}

func clip(value string, width int) string {
	if uniseg.StringWidth(value) <= width {
		return value
	}
	var out strings.Builder
	g := uniseg.NewGraphemes(value)
	used := 0
	for g.Next() {
		if used+g.Width() > width-3 {
			break
		}
		used += g.Width()
		out.WriteString(g.Str())
	}
	return out.String() + "..."
}

func row(label, value string) string {
	value = clip(value, tooltipColumns-len(label)-2)
	return label + strings.Repeat(" ", tooltipColumns-len(label)-uniseg.StringWidth(value)) + value
}

func formatCount(n int64) string {
	switch {
	case n >= 1000000:
		return fmt.Sprintf("%.1fm", float64(n)/1000000)
	case n >= 10000:
		return fmt.Sprintf("%.0fk", float64(n)/1000)
	case n >= 1000:
		return fmt.Sprintf("%.1fk", float64(n)/1000)
	default:
		return fmt.Sprint(n)
	}
}

func formatBytes(n int64) string {
	value, unit := float64(n), 0
	units := []string{"B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB"}
	for value >= 1024 && unit < len(units)-1 {
		value /= 1024
		unit++
	}
	if unit == 0 || value >= 10 {
		return fmt.Sprintf("%.0f %s", value, units[unit])
	}
	return fmt.Sprintf("%.1f %s", value, units[unit])
}
