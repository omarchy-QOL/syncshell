package session

import (
	"context"
	"encoding/json"
	"net/http"
	"slices"
	"sync/atomic"
	"testing"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
)

func TestRemoteSharingStatesHydrateAndRecover(t *testing.T) {
	api := &testAPI{}
	var fail atomic.Bool
	var accepted atomic.Bool
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/rest/config/folders" {
			folders := []syncthing.Folder{}
			for _, id := range []string{"valid", "paused", "notSharing", "unknown", "unexpected"} {
				folders = append(folders, syncthing.Folder{ID: id,
					Devices: []syncthing.FolderDevice{syncthing.NewFolderDevice("REMOTE")}})
			}
			_ = json.NewEncoder(w).Encode(folders)
			return
		}
		if r.URL.Path == "/rest/db/completion" {
			if r.Method != http.MethodGet || r.URL.Query().Get("device") != "REMOTE" ||
				r.Header.Get("X-API-Key") != sessionTestKey {
				t.Error("completion must be an authenticated per-device GET")
			}
			if fail.Load() {
				http.Error(w, "unavailable", http.StatusServiceUnavailable)
				return
			}
			state := r.URL.Query().Get("folder")
			if accepted.Load() {
				state = "valid"
			}
			_ = json.NewEncoder(w).Encode(syncthing.FolderCompletion{RemoteState: state})
			return
		}
		api.ServeHTTP(w, r)
	})
	s := newTestSession(t, handler, "inactive", "LOCAL-ID")
	check := func(allUnknown, allValid bool) {
		t.Helper()
		snapshot, err := s.Refresh(context.Background())
		if err != nil || !snapshot.State.Connection.Fresh {
			t.Fatalf("optional completion failed the local snapshot: %v", err)
		}
		for _, folder := range snapshot.State.Folders {
			want := folder.ID
			if allUnknown || want == "unexpected" {
				want = "unknown"
			}
			if allValid {
				want = "valid"
			}
			if got := folder.Devices[0].RemoteState; got != want {
				t.Errorf("%s remote state = %s, want %s", folder.ID, got, want)
			}
		}
	}
	check(false, false)
	fail.Store(true)
	check(true, false)
	fail.Store(false)
	accepted.Store(true)
	check(false, true)
}

func TestRemoteSharingSkipsUnavailablePeersAndBoundsConcurrency(t *testing.T) {
	var requests, running, maximum atomic.Int32
	api := &testAPI{}
	s := newTestSession(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rest/db/completion" {
			api.ServeHTTP(w, r)
			return
		}
		requests.Add(1)
		current := running.Add(1)
		defer running.Add(-1)
		for current > maximum.Load() {
			previous := maximum.Load()
			if current <= previous || maximum.CompareAndSwap(previous, current) {
				break
			}
		}
		if r.URL.Query().Get("device") != "REMOTE" || r.URL.Query().Get("folder") == "local-paused" {
			t.Error("queried a local, paused or disconnected target")
		}
		time.Sleep(time.Millisecond)
		writeSessionJSON(w, `{"remoteState":"valid"}`)
	}), "inactive", "LOCAL-ID")
	devices := []syncthing.Device{{DeviceID: "LOCAL-ID"}, {DeviceID: "REMOTE"},
		{DeviceID: "OFFLINE"}, {DeviceID: "PAUSED", Paused: true}}
	connections := syncthing.Connections{Connections: map[string]syncthing.Connection{
		"LOCAL-ID": {Connected: true}, "REMOTE": {Connected: true}, "PAUSED": {Connected: true},
	}}
	folders := make([]Folder, 21)
	for i := range folders {
		folders[i].ID = "folder"
		for _, device := range devices {
			folders[i].Devices = append(folders[i].Devices,
				FolderDevice{ID: device.DeviceID, RemoteState: "unknown"})
		}
	}
	folders[20].ID, folders[20].Paused = "local-paused", true
	s.loadRemoteSharing(context.Background(), folders, devices, connections, "LOCAL-ID")
	if requests.Load() != 20 || maximum.Load() > 4 {
		t.Fatalf("requests=%d concurrent=%d", requests.Load(), maximum.Load())
	}
	for _, folder := range folders {
		for _, member := range folder.Devices {
			want := "unknown"
			if member.ID == "REMOTE" && !folder.Paused {
				want = "valid"
			}
			if member.RemoteState != want {
				t.Errorf("%s/%s state=%s want=%s", folder.ID, member.ID, member.RemoteState, want)
			}
		}
	}
}

func TestRemoteSharingCancellationLeavesUnknown(t *testing.T) {
	api := &testAPI{}
	s := newTestSession(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/rest/db/completion" {
			<-r.Context().Done()
			return
		}
		api.ServeHTTP(w, r)
	}), "inactive", "LOCAL-ID")
	folders := []Folder{{ID: "folder", Devices: []FolderDevice{{ID: "REMOTE", RemoteState: "unknown"}}}}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
	defer cancel()
	started := time.Now()
	s.loadRemoteSharing(ctx, folders, []syncthing.Device{{DeviceID: "REMOTE"}},
		syncthing.Connections{Connections: map[string]syncthing.Connection{"REMOTE": {Connected: true}}}, "LOCAL-ID")
	if time.Since(started) > time.Second || folders[0].Devices[0].RemoteState != "unknown" {
		t.Fatal("cancelled peer lookup blocked or falsely confirmed sharing")
	}
}

func TestSharingEventsRefreshRemoteState(t *testing.T) {
	for _, kind := range []string{"ClusterConfigReceived", "FolderCompletion"} {
		if !slices.Contains(eventTypes, kind) || !requiresHydration([]syncthing.Event{{Type: kind}}) {
			t.Errorf("%s does not refresh sharing state", kind)
		}
	}
}
