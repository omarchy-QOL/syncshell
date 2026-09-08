package session

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
)

func TestEventDiscontinuity(t *testing.T) {
	tests := []struct {
		name   string
		cursor int64
		ids    []int64
		gap    bool
	}{
		{"ordered", 5, []int64{6, 7}, false},
		{"gap", 5, []int64{7}, true},
		{"restart", 5, []int64{2}, true},
		{"initial tail", 0, []int64{10, 11}, false},
		{"internal gap", 0, []int64{10, 12}, true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			events := make([]syncthing.Event, len(test.ids))
			for index, id := range test.ids {
				events[index].ID = id
			}
			if actual := eventDiscontinuity(test.cursor, events); actual != test.gap {
				t.Fatalf("got gap %v, want %v", actual, test.gap)
			}
		})
	}
}

func TestRetryDelayIsBoundedAndJittered(t *testing.T) {
	previous := time.Duration(0)
	for attempt := 0; attempt < 10; attempt++ {
		delay := retryDelay(attempt)
		if delay <= previous && attempt <= 5 {
			t.Fatalf("retry delay did not increase: %v after %v", delay, previous)
		}
		if delay > 9*time.Second {
			t.Fatalf("retry delay is unbounded: %v", delay)
		}
		previous = delay
	}
}

func TestActivityNormalizationRotationAndCleanup(t *testing.T) {
	now := time.Unix(100, 0)
	coreSession := &Session{
		activityRecords: make(map[string]activityRecord),
		current: PublishedSnapshot{Revision: 1, State: Snapshot{
			Connection: Connection{Online: true},
		}},
	}
	events := []syncthing.Event{{Type: "RemoteDownloadProgress",
		Data: []byte(`{"folder":"folder","device":"remote","state":{"b.bin":{},"a.bin":{}}}`)}}
	if !coreSession.processActivityEvents(context.Background(), events, now) {
		t.Fatal("remote progress did not change activity")
	}
	first := coreSession.publishActivity(false, now)
	if len(first.State.Activity.Files) != 2 || first.State.Activity.Current == nil ||
		first.State.Activity.Current.Detail != "Upload a.bin" {
		t.Fatalf("unexpected first activity: %#v", first.State.Activity)
	}
	second := coreSession.publishActivity(true, now.Add(activityCycle))
	if second.State.Activity.Current == nil || second.State.Activity.Current.Detail != "Upload b.bin" {
		t.Fatalf("activity did not rotate: %#v", second.State.Activity)
	}
	disconnect := []syncthing.Event{{Type: "DeviceDisconnected",
		Data: []byte(`{"id":"remote"}`)}}
	if !coreSession.processActivityEvents(context.Background(), disconnect, now) {
		t.Fatal("device disconnect did not clear activity")
	}
	cleared := coreSession.publishActivity(false, now)
	if len(cleared.State.Activity.Files) != 0 || cleared.State.Activity.Current != nil {
		t.Fatalf("activity was not cleared: %#v", cleared.State.Activity)
	}

	started := []syncthing.Event{{Type: "ItemStarted",
		Data: []byte(`{"folder":"folder","item":"old.txt","action":"delete"}`)}}
	coreSession.processActivityEvents(context.Background(), started, now)
	removing := coreSession.publishActivity(false, now)
	if removing.State.Activity.Current == nil ||
		removing.State.Activity.Current.Detail != "Removing old.txt" {
		t.Fatalf("delete activity was not normalized: %#v", removing.State.Activity)
	}
	expired := coreSession.publishActivity(false, now.Add(activityHold+time.Second))
	if len(expired.State.Activity.Files) != 0 {
		t.Fatalf("expired activity remained: %#v", expired.State.Activity)
	}
	download := []syncthing.Event{{Type: "DownloadProgress",
		Data: []byte(`{"folder":{"incoming.bin":{"BytesDone":1,"BytesTotal":2}}}`)}}
	coreSession.processActivityEvents(context.Background(), download, now)
	downloading := coreSession.publishActivity(false, now)
	if downloading.State.Activity.Current == nil ||
		downloading.State.Activity.Current.Action != "syncing" {
		t.Fatalf("download progress was not normalized: %#v", downloading.State.Activity)
	}
	coreSession.processActivityEvents(context.Background(),
		[]syncthing.Event{{Type: "DownloadProgress", Data: []byte(`{}`)}}, now)
	if remaining := coreSession.publishActivity(false, now); len(remaining.State.Activity.Files) != 0 {
		t.Fatalf("completed download remained active: %#v", remaining.State.Activity)
	}
	coreSession.activityMu.Lock()
	for index := 0; index < 40; index++ {
		coreSession.storeActivity("folder", fmt.Sprintf("file-%02d", index),
			"syncing", "", now)
	}
	coreSession.activityMu.Unlock()
	bounded := coreSession.publishActivity(false, now)
	if len(bounded.State.Activity.Files) != maxActivity {
		t.Fatalf("activity bound is %d, want %d",
			len(bounded.State.Activity.Files), maxActivity)
	}
}

func TestLocalIndexUsesCurrentFileInformation(t *testing.T) {
	api := &actionAPI{folders: map[string]syncthing.Folder{},
		devices: []syncthing.Device{{DeviceID: "LOCAL"}},
		pending: syncthing.PendingFolders{}, theme: "default"}
	coreSession := newActionSession(t, api)
	if _, err := coreSession.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	now := time.Unix(100, 0)
	event := syncthing.Event{Type: "LocalIndexUpdated",
		Data: []byte(`{"folder":"folder","filenames":["new.txt","old.txt","directory"]}`)}
	if !coreSession.processActivityEvents(context.Background(), []syncthing.Event{event}, now) {
		t.Fatal("local index did not change activity")
	}
	published := coreSession.publishActivity(false, now)
	if len(published.State.Activity.Files) != 2 || api.rescanCount() != 1 {
		t.Fatalf("unexpected indexed activity: %#v rescans=%d",
			published.State.Activity, api.rescanCount())
	}
	actions := make(map[string]string)
	for _, activity := range published.State.Activity.Files {
		actions[activity.Path] = activity.Action
	}
	if actions["new.txt"] != "syncing" || actions["old.txt"] != "removing" {
		t.Fatalf("indexed actions were not classified: %v", actions)
	}
}

func TestLocalIndexDeletionAfterUserRescan(t *testing.T) {
	tests := []struct {
		name      string
		action    string
		arguments ActionArguments
	}{
		{"folder", "folder.rescan", ActionArguments{FolderID: "folder"}},
		{"all folders", "folder.rescan-all", ActionArguments{}},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			api := &actionAPI{folders: map[string]syncthing.Folder{"folder": {
				ID: "folder", Label: "Folder", Path: t.TempDir(),
			}}, devices: []syncthing.Device{{DeviceID: "LOCAL"}},
				pending: syncthing.PendingFolders{}, theme: "default"}
			coreSession := newActionSession(t, api)
			if _, err := coreSession.Refresh(context.Background()); err != nil {
				t.Fatal(err)
			}
			result := coreSession.Act(context.Background(), test.action,
				test.arguments, "rescan", nil)
			if !result.OK || api.rescanCount() != 1 {
				t.Fatalf("rescan failed: %#v count=%d", result, api.rescanCount())
			}

			now := time.Unix(100, 0)
			event := syncthing.Event{Type: "LocalIndexUpdated",
				Data: []byte(`{"folder":"folder","filenames":[` +
					`"00.bin","01.bin","02.bin","03.bin","04.bin","05.bin",` +
					`"06.bin","07.bin","08.bin","09.bin","10.bin","11.bin",` +
					`"12.bin","13.bin","14.bin","old.txt","16.bin"]}`)}
			if !coreSession.processActivityEvents(context.Background(),
				[]syncthing.Event{event}, now) {
				t.Fatal("local index deletion after rescan was skipped")
			}
			published := coreSession.publishActivity(false, now)
			for _, activity := range published.State.Activity.Files {
				if activity.Path == "old.txt" && activity.Action == "removing" {
					return
				}
			}
			t.Fatalf("removal activity missing: %#v", published.State.Activity)
		})
	}
}

func TestEventLoopReconnectsRehydratesAndCancels(t *testing.T) {
	api := &eventAPI{}
	coreSession := newEventSession(t, api)
	initial, err := coreSession.Refresh(context.Background())
	if err != nil || initial.State.WebUI.Theme != "default" {
		t.Fatalf("initial hydration failed: %#v %v", initial, err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	updates := coreSession.Updates(ctx)
	deadline := time.After(5 * time.Second)
	sawStale, sawRehydrated := false, false
	for !sawRehydrated {
		select {
		case update := <-updates:
			if !update.State.Connection.Fresh {
				sawStale = true
			}
			if update.State.Connection.Fresh && update.State.WebUI.Theme == "dark" {
				sawRehydrated = true
			}
		case <-deadline:
			t.Fatal("event loop did not recover and rehydrate")
		}
	}
	if !sawStale || api.eventCallCount() < 3 {
		t.Fatalf("reconnect evidence incomplete: stale=%v calls=%d",
			sawStale, api.eventCallCount())
	}
	cancelEventUpdates(t, cancel, updates)
}

func TestEventFailuresStillRunScheduledReconciliation(t *testing.T) {
	api := &eventAPI{alwaysFail: true}
	coreSession := newEventSession(t, api)
	if _, err := coreSession.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	coreSession.configMu.Lock()
	coreSession.probeInterval = 20 * time.Millisecond
	coreSession.refreshInterval = 50 * time.Millisecond
	coreSession.configMu.Unlock()

	ctx, cancel := context.WithCancel(context.Background())
	updates := coreSession.Updates(ctx)
	deadline := time.After(3 * time.Second)
	for api.healthCallCount() < 2 {
		select {
		case <-updates:
		case <-deadline:
			t.Fatal("persistent Event API failure starved reconciliation")
		}
	}
	if api.eventCallCount() < 2 {
		t.Fatalf("event retry did not continue: %d", api.eventCallCount())
	}
	cancelEventUpdates(t, cancel, updates)
}

func TestEventLoopRecoversCursor(t *testing.T) {
	for _, name := range []string{"restart", "empty restart", "transient failure"} {
		t.Run(name, func(t *testing.T) {
			api := &eventAPI{}
			calls := 0
			mu := sync.Mutex{}
			progress := func(id int64, path string) syncthing.Event {
				return syncthing.Event{ID: id, Type: "RemoteDownloadProgress",
					Data: []byte(fmt.Sprintf(`{"folder":"folder","device":"remote","state":{%q:{}}}`, path))}
			}
			coreSession := newEventSession(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path != "/rest/events" {
					api.ServeHTTP(w, r)
					return
				}
				mu.Lock()
				defer mu.Unlock()
				calls++
				events := []syncthing.Event{progress(12, "old.txt")}
				if calls == 2 {
					http.Error(w, "temporary", http.StatusServiceUnavailable)
					return
				}
				if calls > 2 {
					if name == "transient failure" {
						events = append(events, progress(13, "new.txt"))
					} else {
						events = []syncthing.Event{progress(1, "new.txt")}
					}
					if name == "empty restart" && calls == 3 {
						events = nil
					}
				}
				since, _ := strconv.ParseInt(r.URL.Query().Get("since"), 10, 64)
				limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
				filtered := make([]syncthing.Event, 0, len(events))
				for _, event := range events {
					if event.ID > since {
						filtered = append(filtered, event)
					}
				}
				if limit > 0 && len(filtered) > limit {
					filtered = filtered[len(filtered)-limit:]
				}
				if len(filtered) == 0 {
					waitContext(r.Context(), 10*time.Millisecond)
				}
				_ = json.NewEncoder(w).Encode(filtered)
			}))
			if _, err := coreSession.Refresh(context.Background()); err != nil {
				t.Fatal(err)
			}
			ctx, cancel := context.WithCancel(context.Background())
			updates := coreSession.Updates(ctx)
			defer cancelEventUpdates(t, cancel, updates)
			deadline := time.After(2 * time.Second)
			for {
				select {
				case update := <-updates:
					files := update.State.Activity.Files
					if len(files) == 0 {
						continue
					}
					if len(files) != 1 || files[0].Path != "new.txt" {
						t.Fatalf("recovery replayed old activity: %#v", files)
					}
					return
				case <-deadline:
					t.Fatal("new activity was not delivered after event recovery")
				}
			}
		})
	}
}

type eventAPI struct {
	mu          sync.Mutex
	eventCalls  int
	healthCalls int
	dark        bool
	alwaysFail  bool
}

func (a *eventAPI) ServeHTTP(writer http.ResponseWriter, request *http.Request) {
	if request.URL.Path == "/rest/events" {
		a.mu.Lock()
		a.eventCalls++
		call := a.eventCalls
		alwaysFail := a.alwaysFail
		if call == 3 {
			a.dark = true
		}
		a.mu.Unlock()
		if alwaysFail {
			http.Error(writer, "temporary", http.StatusServiceUnavailable)
			return
		}
		switch call {
		case 1:
			writeSessionJSON(writer, `[{"id":10,"type":"ConfigSaved","data":{}}]`)
		case 2:
			http.Error(writer, "temporary", http.StatusServiceUnavailable)
		case 3:
			writeSessionJSON(writer, `[{"id":12,"type":"ConfigSaved","data":{}}]`)
		default:
			<-request.Context().Done()
		}
		return
	}
	a.mu.Lock()
	dark := a.dark
	a.mu.Unlock()
	switch request.URL.Path {
	case "/rest/noauth/health":
		a.mu.Lock()
		a.healthCalls++
		a.mu.Unlock()
		writeSessionJSON(writer, `{"status":"OK"}`)
	case "/rest/system/status":
		writeSessionJSON(writer, `{"myID":"LOCAL"}`)
	case "/rest/system/version":
		writeSessionJSON(writer, `{"version":"v2.1.3"}`)
	case "/rest/config/devices", "/rest/config/folders":
		writeSessionJSON(writer, `[]`)
	case "/rest/system/connections":
		writeSessionJSON(writer, `{"connections":{}}`)
	case "/rest/cluster/pending/folders":
		writeSessionJSON(writer, `{}`)
	case "/rest/config/gui":
		if dark {
			writeSessionJSON(writer, `{"theme":"dark"}`)
		} else {
			writeSessionJSON(writer, `{"theme":"default"}`)
		}
	case "/rest/system/paths":
		writeSessionJSON(writer, `{"guiAssets":"/tmp/gui"}`)
	default:
		http.NotFound(writer, request)
	}
}

func (a *eventAPI) eventCallCount() int {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.eventCalls
}

func (a *eventAPI) healthCallCount() int {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.healthCalls
}

func newEventSession(t *testing.T, api http.Handler) *Session {
	t.Helper()
	server := httptest.NewServer(api)
	t.Cleanup(server.Close)
	configPath := filepath.Join(t.TempDir(), "config.xml")
	config := fmt.Sprintf(`<configuration><gui tls="false"><address>%s</address><apikey>%s</apikey></gui></configuration>`,
		strings.TrimPrefix(server.URL, "http://"), sessionTestKey)
	if err := os.WriteFile(configPath, []byte(config), 0o600); err != nil {
		t.Fatal(err)
	}
	coreSession, err := New(context.Background(), Config{
		Discovery:     syncthing.DiscoveryOptions{ConfigPath: configPath},
		ProbeInterval: time.Second,
	})
	if err != nil {
		t.Fatal(err)
	}
	return coreSession
}

func cancelEventUpdates(
	t *testing.T,
	cancel context.CancelFunc,
	updates <-chan PublishedSnapshot,
) {
	t.Helper()
	cancel()
	select {
	case _, open := <-updates:
		if open {
			for range updates {
			}
		}
	case <-time.After(3 * time.Second):
		t.Fatal("event loop did not cancel")
	}
}
