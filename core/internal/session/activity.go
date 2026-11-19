package session

import (
	"context"
	"encoding/json"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
)

const (
	activityHold  = 10 * time.Second
	activityCycle = 2500 * time.Millisecond
	maxActivity   = 12
	// Syncthing lists a pulled file in LocalIndexUpdated seconds after ItemFinished.
	finishedItemMemory = 30 * time.Second
	maxFinishedItems   = 8192
	// Files often finish in the batch that started them; keep the last name briefly.
	lastFileHold = 1500 * time.Millisecond
)

type activityRecord struct {
	activity Activity
	deviceID string
	expires  time.Time
}

func (s *Session) processActivityEvents(
	ctx context.Context,
	events []syncthing.Event,
	now time.Time,
) bool {
	changed := false
	s.activityMu.Lock()
	defer s.activityMu.Unlock()
	for _, event := range events {
		switch event.Type {
		case "RemoteDownloadProgress":
			changed = s.remoteProgress(event, now) || changed
		case "DownloadProgress":
			changed = s.downloadProgress(event, now) || changed
		case "LocalIndexUpdated":
			changed = s.localIndex(ctx, event, now) || changed
		case "ItemStarted":
			changed = s.itemStarted(event, now) || changed
		case "ItemFinished":
			changed = s.itemFinished(event, now) || changed
		case "DeviceDisconnected":
			changed = s.deviceDisconnected(event) || changed
		}
	}
	return changed
}

func (s *Session) downloadProgress(event syncthing.Event, now time.Time) bool {
	var data map[string]map[string]json.RawMessage
	if json.Unmarshal(event.Data, &data) != nil {
		return false
	}
	present := make(map[string]struct{})
	changed := false
	for folderID, files := range data {
		for name := range files {
			key := boundedIdentifier(folderID) + "\x00" + boundedPath(name) + "\x00syncing"
			present[key] = struct{}{}
			changed = s.storeActivity(folderID, name, "syncing", "", now) || changed
		}
	}
	for key, record := range s.activityRecords {
		if record.activity.Action != "syncing" {
			continue
		}
		if _, exists := present[key]; !exists {
			delete(s.activityRecords, key)
			changed = true
		}
	}
	return changed
}

func (s *Session) remoteProgress(event syncthing.Event, now time.Time) bool {
	var data struct {
		Folder string                     `json:"folder"`
		Device string                     `json:"device"`
		State  map[string]json.RawMessage `json:"state"`
	}
	if json.Unmarshal(event.Data, &data) != nil || data.Folder == "" {
		return false
	}
	changed := false
	if len(data.State) == 0 {
		for key, record := range s.activityRecords {
			if record.activity.FolderID == data.Folder && record.deviceID == data.Device &&
				record.activity.Action == "upload" {
				delete(s.activityRecords, key)
				changed = true
			}
		}
		return changed
	}
	for name := range data.State {
		changed = s.storeActivity(data.Folder, name, "upload", data.Device, now) || changed
	}
	return changed
}

// rememberFinished lets localIndex skip files the event stream already reported.
func (s *Session) rememberFinished(folderID, path string, now time.Time) {
	if s.finishedItems == nil || len(s.finishedItems) >= maxFinishedItems {
		for key, expires := range s.finishedItems {
			if !expires.After(now) {
				delete(s.finishedItems, key)
			}
		}
		if s.finishedItems == nil || len(s.finishedItems) >= maxFinishedItems {
			s.finishedItems = make(map[string]time.Time)
		}
	}
	s.finishedItems[folderID+"\x00"+path] = now.Add(finishedItemMemory)
}

// rescanSubdirectory runs in the background: Syncthing answers only once the
// scan ends, which waits for any pull. A directory already being rescanned is
// not asked again, so repeated index events cannot pile up requests.
func (s *Session) rescanSubdirectory(ctx context.Context, folderID, subdirectory string) {
	key := folderID + "\x00" + subdirectory
	s.rescansMu.Lock()
	if s.rescansInFlight[key] {
		s.rescansMu.Unlock()
		return
	}
	if s.rescansInFlight == nil {
		s.rescansInFlight = make(map[string]bool)
	}
	s.rescansInFlight[key] = true
	s.rescansMu.Unlock()
	go func() {
		defer func() {
			s.rescansMu.Lock()
			delete(s.rescansInFlight, key)
			s.rescansMu.Unlock()
		}()
		_ = s.client.RescanSubdirectory(ctx, folderID, subdirectory)
	}()
}

func (s *Session) rescanInFlight(folderID, subdirectory string) bool {
	s.rescansMu.Lock()
	defer s.rescansMu.Unlock()
	return s.rescansInFlight[folderID+"\x00"+subdirectory]
}

func (s *Session) localIndex(ctx context.Context, event syncthing.Event, now time.Time) bool {
	var data struct {
		Folder    string   `json:"folder"`
		Filenames []string `json:"filenames"`
	}
	if json.Unmarshal(event.Data, &data) != nil || data.Folder == "" {
		return false
	}
	changed := false
	names := make([]string, 0, 16)
	for _, name := range data.Filenames {
		if expires, ok := s.finishedItems[data.Folder+"\x00"+name]; ok && expires.After(now) {
			continue
		}
		if names = append(names, name); len(names) == 16 {
			break
		}
	}
	for _, name := range names {
		info, err := s.currentFileInfo(ctx, data.Folder, name)
		entry := info.Local
		if entry == nil {
			entry = info.Global
		}
		if err != nil || entry == nil {
			changed = s.storeActivity(data.Folder, name, "syncing", "", now) || changed
			continue
		}
		if fileType(entry.Type) == "directory" && !entry.Deleted {
			s.rescanSubdirectory(ctx, data.Folder, name)
			continue
		}
		action := "syncing"
		if entry.Deleted {
			action = "removing"
		}
		changed = s.storeActivity(data.Folder, name, action, "", now) || changed
	}
	return changed
}

func (s *Session) currentFileInfo(
	ctx context.Context,
	folderID string,
	name string,
) (syncthing.FileInfo, error) {
	var info syncthing.FileInfo
	var err error
	for attempt := 0; attempt < 3; attempt++ {
		candidate, candidateErr := s.client.FileInfo(ctx, folderID, name)
		if candidateErr == nil && (candidate.Local != nil || candidate.Global != nil) {
			info, err = candidate, nil
			entry := info.Local
			if entry == nil {
				entry = info.Global
			}
			if entry != nil && entry.Deleted {
				return info, nil
			}
		} else if candidateErr != nil {
			err = candidateErr
		}
		if attempt < 2 && !waitContext(ctx, time.Duration(attempt+1)*50*time.Millisecond) {
			break
		}
	}
	return info, err
}

func (s *Session) itemStarted(event syncthing.Event, now time.Time) bool {
	var data struct {
		Folder string `json:"folder"`
		Item   string `json:"item"`
		Action string `json:"action"`
	}
	if json.Unmarshal(event.Data, &data) != nil || data.Folder == "" || data.Item == "" {
		return false
	}
	action := "syncing"
	if strings.Contains(strings.ToLower(data.Action), "delete") {
		action = "removing"
	}
	return s.storeActivity(data.Folder, data.Item, action, "", now)
}

func (s *Session) itemFinished(event syncthing.Event, now time.Time) bool {
	var data struct {
		Folder string `json:"folder"`
		Item   string `json:"item"`
	}
	if json.Unmarshal(event.Data, &data) != nil {
		return false
	}
	s.rememberFinished(data.Folder, data.Item, now)
	changed := false
	for key, record := range s.activityRecords {
		if record.activity.FolderID == data.Folder && record.activity.Path == data.Item {
			last := record.activity
			s.lastFile, s.lastFileUntil = &last, now.Add(lastFileHold)
			delete(s.activityRecords, key)
			changed = true
		}
	}
	return changed
}

func (s *Session) deviceDisconnected(event syncthing.Event) bool {
	var data struct {
		ID string `json:"id"`
	}
	if json.Unmarshal(event.Data, &data) != nil || data.ID == "" {
		return false
	}
	changed := false
	for key, record := range s.activityRecords {
		if record.deviceID == data.ID {
			delete(s.activityRecords, key)
			changed = true
		}
	}
	return changed
}

func (s *Session) storeActivity(
	folderID string,
	path string,
	action string,
	deviceID string,
	now time.Time,
) bool {
	folderID, path = boundedIdentifier(folderID), boundedPath(path)
	if folderID == "" || path == "" {
		return false
	}
	key := folderID + "\x00" + path + "\x00" + action
	detail := filepath.Base(path)
	switch action {
	case "upload":
		detail = "Upload " + detail
	case "removing":
		detail = "Removing " + detail
	}
	record := activityRecord{activity: Activity{FolderID: folderID, Path: path,
		Action: action, Detail: boundedLabel(detail)}, deviceID: boundedIdentifier(deviceID),
		expires: now.Add(activityHold)}
	_, exists := s.activityRecords[key]
	replaced := false
	for currentKey, current := range s.activityRecords {
		if currentKey != key && current.activity.FolderID == folderID &&
			current.activity.Path == path {
			delete(s.activityRecords, currentKey)
			replaced = true
		}
	}
	s.activityRecords[key] = record
	if len(s.activityRecords) > maxActivity {
		keys := sortedActivityKeys(s.activityRecords)
		delete(s.activityRecords, keys[0])
	}
	return !exists || replaced
}

func (s *Session) publishActivity(advance bool, now time.Time) PublishedSnapshot {
	s.activityMu.Lock()
	for key, record := range s.activityRecords {
		if !record.expires.After(now) {
			delete(s.activityRecords, key)
		}
	}
	keys := sortedActivityKeys(s.activityRecords)
	if len(keys) == 0 {
		s.activityIndex = 0
	} else if advance {
		s.activityIndex = (s.activityIndex + 1) % len(keys)
	} else if s.activityIndex >= len(keys) {
		s.activityIndex = 0
	}
	activity := ActivityState{Files: make([]Activity, 0, len(keys))}
	for _, key := range keys {
		activity.Files = append(activity.Files, s.activityRecords[key].activity)
	}
	if len(activity.Files) > 0 {
		current := activity.Files[s.activityIndex]
		activity.Current = &current
	} else if s.lastFile != nil && s.lastFileUntil.After(now) {
		current := *s.lastFile
		activity.Current = &current
	}
	s.activityMu.Unlock()

	s.stateMu.Lock()
	if s.current.Revision != 0 && !activityEqual(s.current.State.Activity, activity) {
		s.current.State.Activity = activity
		s.current.Revision++
	}
	published := clonePublished(s.current)
	s.stateMu.Unlock()
	return published
}

func sortedActivityKeys(records map[string]activityRecord) []string {
	keys := make([]string, 0, len(records))
	for key := range records {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

func activityEqual(first, second ActivityState) bool {
	firstCurrent, secondCurrent := "", ""
	if first.Current != nil {
		firstCurrent = first.Current.FolderID + "\x00" + first.Current.Path + "\x00" + first.Current.Action
	}
	if second.Current != nil {
		secondCurrent = second.Current.FolderID + "\x00" + second.Current.Path + "\x00" + second.Current.Action
	}
	if firstCurrent != secondCurrent || len(first.Files) != len(second.Files) {
		return false
	}
	for index := range first.Files {
		if first.Files[index] != second.Files[index] {
			return false
		}
	}
	return true
}

func fileType(value any) string {
	switch typed := value.(type) {
	case string:
		if strings.Contains(strings.ToLower(typed), "directory") {
			return "directory"
		}
	case float64:
		if typed == 1 {
			return "directory"
		}
	}
	return "file"
}
