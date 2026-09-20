package session

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"slices"
	"sort"
	"strings"
	"sync"
	"testing"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
)

type actionAPI struct {
	mu                sync.Mutex
	folders           map[string]syncthing.Folder
	folderConfigs     map[string]syncthing.FolderConfig
	devices           []syncthing.Device
	pending           syncthing.PendingFolders
	theme             string
	rescans           int
	status            syncthing.FolderStatus
	errors            []syncthing.FolderError
	clearOnRescan     bool
	lastAdd           syncthing.FolderConfig
	lastFolderPatch   map[string]any
	folderPatchCount  int
	lastDeviceAdd     syncthing.DeviceConfig
	pendingDevices    syncthing.PendingDevices
	folderPatchStatus map[string]int
	dropFolderPatch   map[string]bool
	dropThemeResponse bool
	rescanStarted     chan struct{}
	rescanRelease     chan struct{}
	rescanFolders     []string
	rescanFailures    map[string]int
	folderReads       int
}

func TestRecheckFolderErrorsPublishesLatestState(t *testing.T) {
	api := &actionAPI{
		folders: map[string]syncthing.Folder{"folder": {
			ID: "folder", Label: "Folder", Path: t.TempDir(),
		}},
		devices:       []syncthing.Device{{DeviceID: "LOCAL"}},
		pending:       syncthing.PendingFolders{},
		theme:         "default",
		status:        syncthing.FolderStatus{State: "idle", PullErrors: 2, NeedTotalItems: 2},
		errors:        []syncthing.FolderError{{Path: "old", Error: "blocked"}, {Path: "new", Error: "blocked"}},
		clearOnRescan: true,
	}
	coreSession := newActionSession(t, api)
	initial, err := coreSession.Refresh(context.Background())
	if err != nil || initial.State.Counts.FolderProblems != 1 {
		t.Fatalf("initial folder errors missing: %#v %v", initial, err)
	}
	result := coreSession.Act(context.Background(), "folder.recheck-errors",
		ActionArguments{})
	latest := coreSession.Current()
	if !result.OK || api.rescanCount() != 1 || latest.State.Counts.FolderProblems != 0 ||
		latest.State.Folders[0].Status.PullErrors != 0 ||
		len(latest.State.Folders[0].Status.Errors) != 0 {
		t.Fatalf("recheck did not publish the latest state: result=%#v state=%#v",
			result, latest.State)
	}
}

func TestFolderActions(t *testing.T) {
	directory := t.TempDir()
	existing := filepath.Join(directory, "existing")
	added := filepath.Join(directory, "added")
	if err := os.MkdirAll(existing, 0o700); err != nil {
		t.Fatal(err)
	}
	api := &actionAPI{
		folders: map[string]syncthing.Folder{"folder": {
			ID: "folder", Label: "Existing", Path: existing, Paused: false,
		}},
		devices: []syncthing.Device{{DeviceID: "LOCAL", Name: "local"},
			{DeviceID: "REMOTE", Name: "remote"}},
		pending: syncthing.PendingFolders{"offer": {OfferedBy: map[string]syncthing.FolderOffer{
			"REMOTE": {Label: "Offered"},
		}}},
		theme: "default",
	}
	coreSession := newActionSession(t, api)
	if _, err := coreSession.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}

	result := coreSession.Act(context.Background(), "folder.pause",
		ActionArguments{FolderID: "folder"})
	if !result.OK || !api.folder("folder").Paused {
		t.Fatalf("pause failed: %#v", result)
	}
	result = coreSession.Act(context.Background(), "folder.resume",
		ActionArguments{FolderID: "folder"})
	if !result.OK || api.folder("folder").Paused {
		t.Fatalf("resume failed: %#v", result)
	}
	result = coreSession.Act(context.Background(), "folder.rescan",
		ActionArguments{FolderID: "folder"})
	if !result.OK {
		t.Fatalf("rescan failed: %#v", result)
	}
	result = coreSession.Act(context.Background(), "folder.rescan-all",
		ActionArguments{})
	if !result.OK || api.rescanCount() != 2 {
		t.Fatalf("rescan-all failed: %#v count=%d", result, api.rescanCount())
	}
	api.setFolderPaused("folder", true)
	result = coreSession.Act(context.Background(), "folder.rescan-all",
		ActionArguments{})
	if result.OK || result.Error == nil || result.Error.Code != "folder_paused" ||
		api.rescanCount() != 2 {
		t.Fatalf("all-paused rescan was accepted: %#v", result)
	}
	api.setFolderPaused("folder", false)

	if err := os.WriteFile(filepath.Join(existing, "retained.txt"), []byte("retained"), 0o600); err != nil {
		t.Fatal(err)
	}
	if result = coreSession.Act(context.Background(), "folder.pause",
		ActionArguments{FolderID: "folder"}); !result.OK {
		t.Fatal(result.Error)
	}
	result = coreSession.Act(context.Background(), "folder.forget",
		ActionArguments{FolderID: "folder"})
	if !result.OK || api.hasFolder("folder") {
		t.Fatalf("forget failed: %#v", result)
	}
	if _, err := os.Stat(filepath.Join(existing, "retained.txt")); err != nil {
		t.Fatalf("forget removed local data: %v", err)
	}

	if err := os.MkdirAll(added, 0o700); err != nil {
		t.Fatal(err)
	}
	result = coreSession.Act(context.Background(), "folder.add-existing",
		ActionArguments{FolderID: "offer", Path: added, DeviceIDs: []string{"REMOTE"},
			PendingDeviceID: "REMOTE"})
	if !result.OK || !api.hasFolder("offer") {
		t.Fatalf("add existing failed: %#v", result)
	}
	addedDevices := api.addedDeviceIDs()
	if strings.Join(addedDevices, ",") != "LOCAL,REMOTE" {
		t.Fatalf("unexpected added devices: %v", addedDevices)
	}

	result = coreSession.Act(context.Background(), "folder.add-existing",
		ActionArguments{FolderID: "offer", Path: added})
	if result.OK || result.Error == nil || result.Error.Code != "folder_exists" {
		t.Fatalf("duplicate folder accepted: %#v", result)
	}
	overlap := filepath.Join(added, "nested")
	if err := os.Mkdir(overlap, 0o700); err != nil {
		t.Fatal(err)
	}
	result = coreSession.Act(context.Background(), "folder.add-existing",
		ActionArguments{FolderID: "overlap", Path: overlap})
	if result.OK || result.Error == nil || result.Error.Code != "path_overlap" {
		t.Fatalf("overlapping path accepted: %#v", result)
	}
}

func TestRescanAllSelectsEndpointAndSortedTargets(t *testing.T) {
	tests := []struct {
		name         string
		folders      map[string]syncthing.Folder
		wantRequests []string
		wantTargets  []string
	}{
		{
			name: "all active uses global endpoint",
			folders: map[string]syncthing.Folder{
				"z": {ID: "z", Path: t.TempDir()},
				"a": {ID: "a", Path: t.TempDir()},
			},
			wantRequests: []string{""},
			wantTargets:  []string{"a", "z"},
		},
		{
			name: "paused folders use active endpoints",
			folders: map[string]syncthing.Folder{
				"z": {ID: "z", Path: t.TempDir()},
				"m": {ID: "m", Path: t.TempDir(), Paused: true},
				"a": {ID: "a", Path: t.TempDir()},
			},
			wantRequests: []string{"a", "z"},
			wantTargets:  []string{"a", "z"},
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			api := &actionAPI{folders: test.folders,
				devices: []syncthing.Device{{DeviceID: "LOCAL"}},
				pending: syncthing.PendingFolders{}, theme: "default"}
			coreSession := newActionSession(t, api)
			if _, err := coreSession.Refresh(context.Background()); err != nil {
				t.Fatal(err)
			}
			result := coreSession.Act(context.Background(), "folder.rescan-all",
				ActionArguments{})
			data, ok := result.Data.(RescanResult)
			if !result.OK || !ok || data.State != "completed" ||
				!slices.Equal(data.TargetFolderIDs, test.wantTargets) ||
				len(data.RunningFolderIDs) != 0 {
				t.Fatalf("unexpected rescan result: %#v", result)
			}
			api.mu.Lock()
			requests := append([]string(nil), api.rescanFolders...)
			api.mu.Unlock()
			sort.Strings(requests)
			if !slices.Equal(requests, test.wantRequests) {
				t.Fatalf("rescan requests = %v, want %v", requests, test.wantRequests)
			}
		})
	}
}

func TestRescanAllRejectsFoldersOutsideThePublishedSnapshot(t *testing.T) {
	root := t.TempDir()
	folders := make(map[string]syncthing.Folder, maxFolders+1)
	for index := 0; index <= maxFolders; index++ {
		id := fmt.Sprintf("folder-%03d", index)
		folders[id] = syncthing.Folder{ID: id, Path: filepath.Join(root, id)}
	}
	api := &actionAPI{
		folders: folders,
		devices: []syncthing.Device{{DeviceID: "LOCAL"}},
		pending: syncthing.PendingFolders{},
		theme:   "default",
	}
	coreSession := newActionSession(t, api)
	if _, err := coreSession.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}

	result := coreSession.Act(context.Background(), "folder.rescan-all",
		ActionArguments{})
	if result.OK || result.Error == nil || result.Error.Code != "folder_limit" {
		t.Fatalf("oversized rescan-all was accepted: %#v", result)
	}
	if api.rescanCount() != 0 {
		t.Fatalf("oversized rescan-all issued %d requests", api.rescanCount())
	}
}

func TestRescanResultReportsOnlyTimedOutScanningTargets(t *testing.T) {
	targets := []string{"a", "b", "c"}
	attempts := []rescanAttempt{
		{disposition: syncthing.RescanCompleted},
		{disposition: syncthing.RescanRunning},
		{disposition: syncthing.RescanRunning},
	}
	snapshot := Snapshot{Folders: []Folder{
		{ID: "a", Status: FolderStatus{State: "scanning"}},
		{ID: "b", Status: FolderStatus{State: "scan-waiting"}},
		{ID: "c", Status: FolderStatus{State: "idle"}},
	}}
	result := rescanResult(targets, attempts, snapshot)
	if result.State != "running" ||
		!slices.Equal(result.RunningFolderIDs, []string{"b"}) {
		t.Fatalf("unexpected mixed rescan result: %#v", result)
	}
}

func TestMixedRescanAttemptsEveryTargetAndRefreshesAfterFailure(t *testing.T) {
	api := &actionAPI{
		folders: map[string]syncthing.Folder{
			"a":      {ID: "a", Path: t.TempDir()},
			"b":      {ID: "b", Path: t.TempDir()},
			"paused": {ID: "paused", Path: t.TempDir(), Paused: true},
		},
		devices: []syncthing.Device{{DeviceID: "LOCAL"}},
		pending: syncthing.PendingFolders{}, theme: "default",
		rescanFailures: map[string]int{"a": http.StatusInternalServerError},
	}
	coreSession := newActionSession(t, api)
	if _, err := coreSession.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	result := coreSession.Act(context.Background(), "folder.rescan-all",
		ActionArguments{})
	if result.OK || result.Error == nil || result.Error.Code != "http" {
		t.Fatalf("failed rescan-all was accepted: %#v", result)
	}
	api.mu.Lock()
	requests := append([]string(nil), api.rescanFolders...)
	reads := api.folderReads
	api.mu.Unlock()
	sort.Strings(requests)
	if !slices.Equal(requests, []string{"a", "b"}) {
		t.Fatalf("rescan requests = %v, want both active folders", requests)
	}
	if reads < 3 {
		t.Fatalf("failed rescan did not refresh state: folder reads=%d", reads)
	}
}

func TestSuggestionThemeAndActionShape(t *testing.T) {
	api := &actionAPI{folders: map[string]syncthing.Folder{},
		devices: []syncthing.Device{{DeviceID: "LOCAL"}},
		pending: syncthing.PendingFolders{}, theme: "default"}
	coreSession := newActionSession(t, api)
	if _, err := coreSession.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	result := coreSession.Act(context.Background(), "folder.rescan-all",
		ActionArguments{})
	if result.OK || result.Error == nil || result.Error.Code != "folder_missing" {
		t.Fatalf("empty rescan-all was accepted: %#v", result)
	}
	result = coreSession.Act(context.Background(), "folder.suggest-id",
		ActionArguments{})
	data, ok := result.Data.(map[string]string)
	if !result.OK || !ok || data["folderId"] != "abcdefghij" {
		t.Fatalf("suggestion failed: %#v", result)
	}
	result = coreSession.Act(context.Background(), "webui.set-theme",
		ActionArguments{Theme: "syncthing-omarchy"})
	if !result.OK || api.currentTheme() != "syncthing-omarchy" {
		t.Fatalf("theme action failed: %#v", result)
	}
	api.setDropThemeResponse(true)
	result = coreSession.Act(context.Background(), "webui.set-theme",
		ActionArguments{Theme: "default"})
	if !result.OK || api.currentTheme() != "default" {
		t.Fatalf("theme response-drop recovery failed: %#v", result)
	}
	result = coreSession.Act(context.Background(), "folder.rescan-all",
		ActionArguments{Theme: "unexpected"})
	if result.OK || result.Error == nil || result.Error.Code != "invalid_action" {
		t.Fatalf("irrelevant action arguments were accepted: %#v", result)
	}
}

func TestDeviceAndSharingActionsPreserveFolderConfiguration(t *testing.T) {
	remoteID := "AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG-HHHHHHH"
	newID := "IIIIIII-JJJJJJJ-KKKKKKK-LLLLLLL-MMMMMMM-NNNNNNN-OOOOOOO-PPPPPPP"
	folderPath := t.TempDir()
	api := &actionAPI{
		folders: map[string]syncthing.Folder{"folder": {
			ID: "folder", Label: "Folder", Path: folderPath,
			Devices: []syncthing.FolderDevice{{DeviceID: "LOCAL"}, {DeviceID: remoteID}},
		}},
		folderConfigs: map[string]syncthing.FolderConfig{"folder": {
			"id": "folder", "path": folderPath, "rescanIntervalS": float64(17),
			"devices": []any{
				map[string]any{"deviceID": "LOCAL"},
				map[string]any{"deviceID": remoteID,
					"encryptionPassword": "kept-secret-setting"},
			},
		}},
		devices: []syncthing.Device{{DeviceID: "LOCAL", Name: "local"},
			{DeviceID: remoteID, Name: "remote"}},
		pending: syncthing.PendingFolders{},
		pendingDevices: syncthing.PendingDevices{
			newID: {Name: "xps", Address: "tcp://192.0.2.8:22000"},
		},
		theme: "default",
	}
	coreSession := newActionSession(t, api)
	if _, err := coreSession.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}

	result := coreSession.Act(context.Background(), "folder.set-sharing",
		ActionArguments{FolderID: "folder", DeviceIDs: []string{remoteID}})
	if !result.OK {
		t.Fatalf("set sharing failed: %#v", result)
	}
	if len(api.lastFolderPatch) != 1 {
		t.Fatalf("sharing replaced unrelated folder fields: %#v", api.lastFolderPatch)
	}
	entries, _ := api.lastFolderPatch["devices"].([]any)
	remote, _ := entries[1].(map[string]any)
	if remote["encryptionPassword"] != "kept-secret-setting" {
		t.Fatalf("sharing lost device entry fields: %#v", entries)
	}

	result = coreSession.Act(context.Background(), "device.remove-folder-shares",
		ActionArguments{DeviceID: remoteID, FolderIDs: []string{"folder"}})
	if !result.OK {
		t.Fatalf("remove device share failed: %#v", result)
	}
	entries, _ = api.lastFolderPatch["devices"].([]any)
	if len(entries) != 1 || entries[0].(map[string]any)["deviceID"] != "LOCAL" {
		t.Fatalf("device share removal changed the wrong entries: %#v", entries)
	}

	result = coreSession.Act(context.Background(), "device.add",
		ActionArguments{DeviceID: newID, DeviceName: "xps"})
	if !result.OK || api.lastDeviceAdd["compression"] != "metadata" ||
		api.lastDeviceAdd["name"] != "xps" {
		t.Fatalf("add device did not preserve defaults: %#v %#v",
			result, api.lastDeviceAdd)
	}

	result = coreSession.Act(context.Background(), "device.dismiss-pending",
		ActionArguments{DeviceID: newID})
	if !result.OK || len(api.pendingDevices) != 0 {
		t.Fatalf("dismiss pending device failed: %#v %#v", result, api.pendingDevices)
	}

	result = coreSession.Act(context.Background(), "device.remove",
		ActionArguments{DeviceID: remoteID})
	if !result.OK {
		t.Fatalf("remove device failed: %#v", result)
	}
	for _, device := range coreSession.Current().State.Devices {
		if device.ID == remoteID {
			t.Fatalf("removed device remains published: %#v", device)
		}
	}
}

func TestDeviceFolderRemovalValidatesEveryFolderBeforeWriting(t *testing.T) {
	remoteID := "AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG-HHHHHHH"
	folder := func(id string) syncthing.Folder {
		return syncthing.Folder{ID: id, Label: id, Path: t.TempDir(),
			Devices: []syncthing.FolderDevice{
				syncthing.NewFolderDevice("LOCAL"),
				syncthing.NewFolderDevice(remoteID),
			}}
	}
	folderA := folder("a")
	folderB := folder("b")
	api := &actionAPI{
		folders: map[string]syncthing.Folder{
			"a": folderA,
			"b": folderB,
		},
		folderConfigs: map[string]syncthing.FolderConfig{
			"a": {"id": "a", "path": folderA.Path, "devices": []any{
				map[string]any{"deviceID": "LOCAL"},
				map[string]any{"deviceID": remoteID},
			}},
			"b": {"id": "b", "path": folderB.Path, "devices": []any{
				map[string]any{"deviceID": "LOCAL"},
				map[string]any{"name": "missing device ID"},
			}},
		},
		devices: []syncthing.Device{{DeviceID: "LOCAL"}, {DeviceID: remoteID}},
		pending: syncthing.PendingFolders{},
		theme:   "default",
	}
	coreSession := newActionSession(t, api)
	if _, err := coreSession.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}

	result := coreSession.Act(context.Background(), "device.remove-folder-shares",
		ActionArguments{DeviceID: remoteID, FolderIDs: []string{"a", "b"}})
	if result.Error == nil || result.Error.Code != "schema" {
		t.Fatalf("invalid folder configuration was accepted: %#v", result)
	}
	if api.folderPatchCountValue() != 0 {
		t.Fatal("folder removal wrote a partial update before validation completed")
	}
}

func TestFolderSharingRejectsChangedFolderBeforeWriting(t *testing.T) {
	remoteID := "AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG-HHHHHHH"
	api := &actionAPI{
		folders: map[string]syncthing.Folder{"folder": {
			ID: "folder", Path: t.TempDir(), Devices: []syncthing.FolderDevice{
				syncthing.NewFolderDevice("LOCAL"),
				syncthing.NewFolderDevice(remoteID),
			},
		}},
		devices: []syncthing.Device{{DeviceID: "LOCAL"}, {DeviceID: remoteID}},
		pending: syncthing.PendingFolders{}, theme: "default",
	}
	coreSession := newActionSession(t, api)
	if _, err := coreSession.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	api.setFolderPath("folder", t.TempDir())

	result := coreSession.Act(context.Background(), "folder.set-sharing",
		ActionArguments{FolderID: "folder", DeviceIDs: []string{remoteID}})
	if result.Error == nil || result.Error.Code != "folder_changed" {
		t.Fatalf("sharing accepted a replaced folder: %#v", result)
	}
	if api.folderPatchCountValue() != 0 {
		t.Fatal("sharing wrote after folder identity changed")
	}
}

func TestDeviceFolderRemovalRefreshesAfterPartialWrite(t *testing.T) {
	remoteID := "AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG-HHHHHHH"
	folder := func(id string) syncthing.Folder {
		return syncthing.Folder{ID: id, Path: t.TempDir(),
			Devices: []syncthing.FolderDevice{
				syncthing.NewFolderDevice("LOCAL"),
				syncthing.NewFolderDevice(remoteID),
			}}
	}
	api := &actionAPI{
		folders: map[string]syncthing.Folder{"a": folder("a"), "b": folder("b")},
		devices: []syncthing.Device{{DeviceID: "LOCAL"}, {DeviceID: remoteID}},
		pending: syncthing.PendingFolders{}, theme: "default",
		folderPatchStatus: map[string]int{"b": http.StatusInternalServerError},
	}
	coreSession := newActionSession(t, api)
	if _, err := coreSession.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}

	result := coreSession.Act(context.Background(), "device.remove-folder-shares",
		ActionArguments{DeviceID: remoteID, FolderIDs: []string{"a", "b"}})
	if result.Error == nil || result.Error.Code != "http" {
		t.Fatalf("partial write did not report the server error: %#v", result)
	}
	if hasPublicFolderDevice(coreSession.Current().State.Folders, "a", remoteID) {
		t.Fatal("published state did not refresh the successful first write")
	}
	if !hasPublicFolderDevice(coreSession.Current().State.Folders, "b", remoteID) {
		t.Fatal("failed second write changed the published relationship")
	}
}

func TestAmbiguousFolderPatchRefreshesAppliedState(t *testing.T) {
	remoteID := "AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG-HHHHHHH"
	api := &actionAPI{
		folders: map[string]syncthing.Folder{"folder": {
			ID: "folder", Path: t.TempDir(), Devices: []syncthing.FolderDevice{
				syncthing.NewFolderDevice("LOCAL"),
				syncthing.NewFolderDevice(remoteID),
			},
		}},
		devices: []syncthing.Device{{DeviceID: "LOCAL"}, {DeviceID: remoteID}},
		pending: syncthing.PendingFolders{}, theme: "default",
		dropFolderPatch: map[string]bool{"folder": true},
	}
	coreSession := newActionSession(t, api)
	if _, err := coreSession.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}

	result := coreSession.Act(context.Background(), "folder.set-sharing",
		ActionArguments{FolderID: "folder"})
	if result.Error == nil || result.Error.Code != "connection" {
		t.Fatalf("dropped response did not report a connection error: %#v", result)
	}
	if hasPublicFolderDevice(coreSession.Current().State.Folders, "folder", remoteID) {
		t.Fatal("ambiguous write did not refresh the applied relationship")
	}
}

func TestActionArgumentShapesRejectUnrelatedFields(t *testing.T) {
	type actionShape struct {
		name    string
		valid   ActionArguments
		allowed map[string]bool
	}
	shapes := []actionShape{
		{"folder.pause", ActionArguments{FolderID: "folder"}, map[string]bool{"folderId": true}},
		{"folder.resume", ActionArguments{FolderID: "folder"}, map[string]bool{"folderId": true}},
		{"folder.rescan", ActionArguments{FolderID: "folder"}, map[string]bool{"folderId": true}},
		{"folder.forget", ActionArguments{FolderID: "folder"}, map[string]bool{"folderId": true}},
		{"folder.rescan-all", ActionArguments{}, map[string]bool{}},
		{"folder.recheck-errors", ActionArguments{}, map[string]bool{}},
		{"folder.suggest-id", ActionArguments{}, map[string]bool{}},
		{"folder.add-existing", ActionArguments{FolderID: "folder", Path: "/tmp/folder",
			Label: "Folder", DeviceIDs: []string{"REMOTE"}, PendingDeviceID: "REMOTE"},
			map[string]bool{"folderId": true, "path": true, "label": true,
				"deviceIds": true, "pendingDeviceId": true}},
		{"folder.set-sharing", ActionArguments{FolderID: "folder",
			DeviceIDs: []string{"REMOTE"}},
			map[string]bool{"folderId": true, "deviceIds": true}},
		{"device.add", ActionArguments{DeviceID: "REMOTE", DeviceName: "Remote"},
			map[string]bool{"deviceId": true, "deviceName": true}},
		{"device.remove", ActionArguments{DeviceID: "REMOTE"},
			map[string]bool{"deviceId": true}},
		{"device.dismiss-pending", ActionArguments{DeviceID: "REMOTE"},
			map[string]bool{"deviceId": true}},
		{"device.remove-folder-shares", ActionArguments{DeviceID: "REMOTE",
			FolderIDs: []string{"folder"}},
			map[string]bool{"deviceId": true, "folderIds": true}},
		{"webui.open", ActionArguments{}, map[string]bool{}},
		{"webui.set-theme", ActionArguments{Theme: "default"},
			map[string]bool{"theme": true}},
		{"lifecycle.start", ActionArguments{}, map[string]bool{}},
		{"lifecycle.stop", ActionArguments{}, map[string]bool{}},
		{"lifecycle.enable", ActionArguments{}, map[string]bool{}},
		{"lifecycle.disable", ActionArguments{}, map[string]bool{}},
	}
	fields := map[string]func(*ActionArguments){
		"folderId":        func(value *ActionArguments) { value.FolderID = "other" },
		"path":            func(value *ActionArguments) { value.Path = "/other" },
		"label":           func(value *ActionArguments) { value.Label = "Other" },
		"deviceIds":       func(value *ActionArguments) { value.DeviceIDs = []string{"OTHER"} },
		"folderIds":       func(value *ActionArguments) { value.FolderIDs = []string{"other"} },
		"pendingDeviceId": func(value *ActionArguments) { value.PendingDeviceID = "OTHER" },
		"deviceId":        func(value *ActionArguments) { value.DeviceID = "OTHER" },
		"deviceName":      func(value *ActionArguments) { value.DeviceName = "Other" },
		"theme":           func(value *ActionArguments) { value.Theme = "other" },
	}
	for _, shape := range shapes {
		t.Run(shape.name, func(t *testing.T) {
			if result := validateActionArguments(shape.name, shape.valid); result != nil {
				t.Fatalf("valid arguments were rejected: %#v", result)
			}
			for name, set := range fields {
				if shape.allowed[name] {
					continue
				}
				value := shape.valid
				set(&value)
				if result := validateActionArguments(shape.name, value); result == nil ||
					result.Error == nil || result.Error.Code != "invalid_action" {
					t.Fatalf("unrelated %s was accepted: %#v", name, result)
				}
			}
		})
	}
}

func TestAddValidationRejectsUnsafeInputs(t *testing.T) {
	devices := []syncthing.Device{{DeviceID: "TRUSTED"},
		{DeviceID: "UNTRUSTED", Untrusted: true}}
	pending := syncthing.PendingFolders{"offer": {OfferedBy: map[string]syncthing.FolderOffer{
		"TRUSTED": {ReceiveEncrypted: true},
	}}}
	if _, result := validateSelectedDevices(ActionArguments{
		FolderID: "offer", DeviceIDs: []string{"UNTRUSTED"}},
		devices, pending, "LOCAL"); result == nil || result.Error == nil ||
		result.Error.Code != "device_invalid" {
		t.Fatalf("untrusted device accepted: %#v", result)
	}
	if _, result := validateSelectedDevices(ActionArguments{
		FolderID: "offer", DeviceIDs: []string{"TRUSTED"}, PendingDeviceID: "TRUSTED"},
		devices, pending, "LOCAL"); result == nil || result.Error == nil ||
		result.Error.Code != "offer_encrypted" {
		t.Fatalf("encrypted offer accepted: %#v", result)
	}
	if _, result := validateSelectedDevices(ActionArguments{
		FolderID: "missing", DeviceIDs: []string{"TRUSTED"}, PendingDeviceID: "TRUSTED"},
		devices, pending, "LOCAL"); result == nil || result.Error == nil ||
		result.Error.Code != "offer_missing" {
		t.Fatalf("missing offer accepted: %#v", result)
	}
	if _, result := canonicalDirectory("relative/path"); result == nil ||
		result.Error == nil || result.Error.Code != "path_invalid" {
		t.Fatalf("relative path accepted: %#v", result)
	}
}

func TestRemoteDeviceValidationUsesOneTrustedPolicy(t *testing.T) {
	devices := []syncthing.Device{
		{DeviceID: "LOCAL"},
		{DeviceID: "B"},
		{DeviceID: "A"},
		{DeviceID: "UNTRUSTED", Untrusted: true},
	}
	selected, result := validateRemoteDevices(
		[]string{" B ", "A", "B"}, devices, "LOCAL")
	if result != nil || strings.Join(selected, ",") != "A,B" {
		t.Fatalf("trusted remotes were not normalized: %#v %#v", selected, result)
	}
	for _, deviceID := range []string{"LOCAL", "UNTRUSTED", "UNKNOWN", ""} {
		if _, result := validateRemoteDevices([]string{deviceID}, devices, "LOCAL"); result == nil || result.Error == nil || result.Error.Code != "device_invalid" {
			t.Fatalf("invalid remote %q was accepted: %#v", deviceID, result)
		}
	}
}

func TestSelectFolderDevicesPreservesSelectedServerFields(t *testing.T) {
	var existing []syncthing.FolderDevice
	if err := json.Unmarshal([]byte(`[
		{"deviceID":"LOCAL","introducedBy":"INTRODUCER"},
		{"deviceID":"REMOTE","encryptionPassword":"kept"},
		{"deviceID":"REMOTE","encryptionPassword":"duplicate"},
		{"deviceID":"REMOVED","compression":"always"}
	]`), &existing); err != nil {
		t.Fatal(err)
	}
	selected := selectFolderDevices(existing,
		[]string{"LOCAL", "REMOTE", "NEW", "REMOTE", ""})
	contents, err := json.Marshal(selected)
	if err != nil {
		t.Fatal(err)
	}
	var decoded []map[string]any
	if err := json.Unmarshal(contents, &decoded); err != nil {
		t.Fatal(err)
	}
	if len(decoded) != 3 || decoded[0]["deviceID"] != "LOCAL" ||
		decoded[0]["introducedBy"] != "INTRODUCER" ||
		decoded[1]["deviceID"] != "REMOTE" ||
		decoded[1]["encryptionPassword"] != "kept" ||
		decoded[2]["deviceID"] != "NEW" {
		t.Fatalf("folder devices were not reconciled safely: %#v", decoded)
	}
}

func TestExistingFolderPathOverlap(t *testing.T) {
	home := t.TempDir()
	wanted := filepath.Join(home, "files", "nested")
	for _, test := range []struct {
		name, configured, home, code string
	}{
		{"absolute", filepath.Join(home, "files"), home, "path_overlap"},
		{"tilde", "~/files", home, "path_overlap"},
		{"home", "~", home, "path_overlap"},
		{"separate", "~/other", home, ""},
		{"relative", "files", home, "path_unresolved"},
		{"unknown home", "~/files", "", "path_unresolved"},
	} {
		t.Run(test.name, func(t *testing.T) {
			folders := []syncthing.Folder{{ID: "existing", Path: test.configured}}
			result := validateUnusedFolder("new", wanted, folders, test.home)
			if test.code == "" {
				if result != nil {
					t.Fatalf("unrelated folder rejected: %#v", result)
				}
			} else if result == nil || result.Error == nil || result.Error.Code != test.code {
				t.Fatalf("expected %s, got %#v", test.code, result)
			}
		})
	}
}

func newActionSession(t *testing.T, api *actionAPI) *Session {
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
		Discovery: syncthing.DiscoveryOptions{ConfigPath: configPath},
	})
	if err != nil {
		t.Fatal(err)
	}
	return coreSession
}

func (a *actionAPI) ServeHTTP(writer http.ResponseWriter, request *http.Request) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if request.URL.Path != "/rest/noauth/health" &&
		request.Header.Get("X-API-Key") != sessionTestKey {
		http.Error(writer, "unauthorized", http.StatusUnauthorized)
		return
	}
	switch {
	case request.URL.Path == "/rest/noauth/health":
		a.write(writer, `{"status":"OK"}`)
	case request.URL.Path == "/rest/system/status":
		a.write(writer, `{"myID":"LOCAL"}`)
	case request.URL.Path == "/rest/system/version":
		a.write(writer, `{"version":"v2.1.3"}`)
	case request.URL.Path == "/rest/config/devices" && request.Method == http.MethodGet:
		a.writeValue(writer, a.devices)
	case request.URL.Path == "/rest/config/devices" && request.Method == http.MethodPost:
		if json.NewDecoder(request.Body).Decode(&a.lastDeviceAdd) != nil {
			http.Error(writer, "bad config", http.StatusBadRequest)
			return
		}
		a.devices = append(a.devices, syncthing.Device{
			DeviceID: a.lastDeviceAdd["deviceID"].(string),
			Name:     fmt.Sprint(a.lastDeviceAdd["name"]),
		})
		writer.WriteHeader(http.StatusOK)
	case strings.HasPrefix(request.URL.Path, "/rest/config/devices/") &&
		request.Method == http.MethodDelete:
		deviceID := strings.TrimPrefix(request.URL.Path, "/rest/config/devices/")
		devices := a.devices[:0]
		for _, device := range a.devices {
			if device.DeviceID != deviceID {
				devices = append(devices, device)
			}
		}
		a.devices = devices
		writer.WriteHeader(http.StatusOK)
	case request.URL.Path == "/rest/config/folders" && request.Method == http.MethodGet:
		a.folderReads++
		folders := make([]syncthing.Folder, 0, len(a.folders))
		for _, folder := range a.folders {
			folders = append(folders, folder)
		}
		a.writeValue(writer, folders)
	case request.URL.Path == "/rest/config/folders" && request.Method == http.MethodPost:
		var config syncthing.FolderConfig
		if json.NewDecoder(request.Body).Decode(&config) != nil {
			http.Error(writer, "bad config", http.StatusBadRequest)
			return
		}
		a.lastAdd = config
		folder := syncthing.Folder{ID: config["id"].(string), Label: config["label"].(string),
			Path: config["path"].(string), Paused: false}
		a.folders[folder.ID] = folder
		writer.WriteHeader(http.StatusOK)
	case strings.HasPrefix(request.URL.Path, "/rest/config/folders/"):
		id := strings.TrimPrefix(request.URL.Path, "/rest/config/folders/")
		folder, exists := a.folders[id]
		if !exists {
			http.NotFound(writer, request)
			return
		}
		switch request.Method {
		case http.MethodGet:
			if config, exists := a.folderConfigs[id]; exists {
				a.writeValue(writer, config)
			} else {
				a.writeValue(writer, folder)
			}
		case http.MethodPatch:
			if status := a.folderPatchStatus[id]; status != 0 {
				http.Error(writer, "folder patch failed", status)
				return
			}
			var patch map[string]any
			_ = json.NewDecoder(request.Body).Decode(&patch)
			a.lastFolderPatch = patch
			a.folderPatchCount++
			if paused, exists := patch["paused"].(bool); exists {
				folder.Paused = paused
			}
			if entries, exists := patch["devices"].([]any); exists {
				folder.Devices = nil
				for _, entry := range entries {
					device, _ := entry.(map[string]any)
					folder.Devices = append(folder.Devices, syncthing.FolderDevice{
						DeviceID: fmt.Sprint(device["deviceID"]),
					})
				}
				if a.folderConfigs != nil {
					a.folderConfigs[id]["devices"] = entries
				}
			}
			a.folders[id] = folder
			if a.dropFolderPatch[id] {
				delete(a.dropFolderPatch, id)
				connection, _, err := writer.(http.Hijacker).Hijack()
				if err == nil {
					_ = connection.Close()
				}
				return
			}
			writer.WriteHeader(http.StatusOK)
		case http.MethodDelete:
			delete(a.folders, id)
			writer.WriteHeader(http.StatusOK)
		}
	case request.URL.Path == "/rest/system/connections":
		a.write(writer, `{"connections":{}}`)
	case request.URL.Path == "/rest/db/status":
		status := a.status
		if status.State == "" {
			status.State = "idle"
		}
		a.writeValue(writer, status)
	case request.URL.Path == "/rest/folder/errors":
		a.writeValue(writer, syncthing.FolderErrors{Errors: a.errors})
	case request.URL.Path == "/rest/cluster/pending/folders":
		a.writeValue(writer, a.pending)
	case request.URL.Path == "/rest/cluster/pending/devices" &&
		request.Method == http.MethodGet:
		a.writeValue(writer, a.pendingDevices)
	case request.URL.Path == "/rest/cluster/pending/devices" &&
		request.Method == http.MethodDelete:
		delete(a.pendingDevices, request.URL.Query().Get("device"))
		writer.WriteHeader(http.StatusOK)
	case request.URL.Path == "/rest/system/discovery":
		a.writeValue(writer, syncthing.DiscoveryCache{})
	case request.URL.Path == "/rest/config/gui" && request.Method == http.MethodGet:
		a.writeValue(writer, syncthing.GUIConfig{Theme: a.theme})
	case request.URL.Path == "/rest/config/gui" && request.Method == http.MethodPatch:
		var patch map[string]string
		_ = json.NewDecoder(request.Body).Decode(&patch)
		a.theme = patch["theme"]
		if a.dropThemeResponse {
			a.dropThemeResponse = false
			connection, _, err := writer.(http.Hijacker).Hijack()
			if err == nil {
				_ = connection.Close()
			}
			return
		}
		writer.WriteHeader(http.StatusOK)
	case request.URL.Path == "/rest/system/paths":
		a.write(writer, `{"guiAssets":"/tmp/gui","baseDir-userHome":"/tmp"}`)
	case request.URL.Path == "/rest/config/defaults/folder":
		a.write(writer, `{"id":"","label":"","path":"","paused":false,"devices":[]}`)
	case request.URL.Path == "/rest/config/defaults/device":
		a.write(writer, `{"addresses":["dynamic"],"compression":"metadata"}`)
	case request.URL.Path == "/rest/svc/random/string":
		a.write(writer, `{"random":"ABCDEFGHIJ"}`)
	case request.URL.Path == "/rest/db/scan":
		a.rescans++
		folderID := request.URL.Query().Get("folder")
		a.rescanFolders = append(a.rescanFolders, folderID)
		if a.rescanStarted != nil {
			select {
			case a.rescanStarted <- struct{}{}:
			default:
			}
		}
		if a.rescanRelease != nil {
			<-a.rescanRelease
		}
		if a.clearOnRescan {
			a.status.PullErrors = 0
			a.status.NeedTotalItems = 0
			a.errors = nil
		}
		if status := a.rescanFailures[folderID]; status != 0 {
			http.Error(writer, "rescan failed", status)
			return
		}
		writer.WriteHeader(http.StatusOK)
	case request.URL.Path == "/rest/db/file":
		name := request.URL.Query().Get("file")
		switch name {
		case "old.txt":
			a.write(writer, `{"local":{"name":"old.txt","type":"FILE_INFO_TYPE_FILE","deleted":true}}`)
		case "directory":
			a.write(writer, `{"local":{"name":"directory","type":"FILE_INFO_TYPE_DIRECTORY","deleted":false}}`)
		default:
			a.writeValue(writer, map[string]any{"local": map[string]any{
				"name": name, "type": "FILE_INFO_TYPE_FILE", "deleted": false,
			}})
		}
	default:
		http.NotFound(writer, request)
	}
}

func (a *actionAPI) folder(id string) syncthing.Folder {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.folders[id]
}

func (a *actionAPI) hasFolder(id string) bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	_, exists := a.folders[id]
	return exists
}

func (a *actionAPI) setFolderPaused(id string, paused bool) {
	a.mu.Lock()
	defer a.mu.Unlock()
	folder := a.folders[id]
	folder.Paused = paused
	a.folders[id] = folder
}

func (a *actionAPI) setFolderPath(id, path string) {
	a.mu.Lock()
	defer a.mu.Unlock()
	folder := a.folders[id]
	folder.Path = path
	a.folders[id] = folder
}

func (a *actionAPI) rescanCount() int {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.rescans
}

func (a *actionAPI) currentTheme() string {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.theme
}

func (a *actionAPI) folderPatchCountValue() int {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.folderPatchCount
}

func (a *actionAPI) setDropThemeResponse(value bool) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.dropThemeResponse = value
}

func (a *actionAPI) addedDeviceIDs() []string {
	a.mu.Lock()
	defer a.mu.Unlock()
	values, _ := a.lastAdd["devices"].([]any)
	ids := make([]string, 0, len(values))
	for _, value := range values {
		device, _ := value.(map[string]any)
		id, _ := device["deviceID"].(string)
		ids = append(ids, id)
	}
	sort.Strings(ids)
	return ids
}

func hasPublicFolderDevice(folders []Folder, folderID, deviceID string) bool {
	for _, folder := range folders {
		if folder.ID != folderID {
			continue
		}
		for _, device := range folder.Devices {
			if device.ID == deviceID {
				return true
			}
		}
	}
	return false
}

func (a *actionAPI) write(writer http.ResponseWriter, value string) {
	writer.Header().Set("Content-Type", "application/json")
	_, _ = writer.Write([]byte(value))
}

func (a *actionAPI) writeValue(writer http.ResponseWriter, value any) {
	writer.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(writer).Encode(value)
}
