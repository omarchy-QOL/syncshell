package session

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
)

var safeName = regexp.MustCompile(`^[A-Za-z0-9._-]+$`)

const rescanAllWorkers = 8

// Act serializes, validates, and executes one domain action.
func (s *Session) Act(ctx context.Context, action string, arguments ActionArguments) ActionResult {
	s.actionMu.Lock()
	defer s.actionMu.Unlock()

	if validation := validateActionArguments(action, arguments); validation != nil {
		return *validation
	}
	switch action {
	case "folder.pause":
		return s.setFolderPaused(ctx, arguments.FolderID, true)
	case "folder.resume":
		return s.setFolderPaused(ctx, arguments.FolderID, false)
	case "folder.rescan":
		return s.rescanFolder(ctx, arguments.FolderID)
	case "folder.rescan-all":
		return s.rescanAll(ctx)
	case "folder.recheck-errors":
		return s.recheckFolderErrors(ctx)
	case "folder.forget":
		return s.forgetFolder(ctx, arguments.FolderID)
	case "folder.add-existing":
		return s.addExistingFolder(ctx, arguments)
	case "folder.set-sharing":
		return s.setFolderSharing(ctx, arguments)
	case "folder.suggest-id":
		return s.suggestFolderID(ctx)
	case "device.add":
		return s.addDevice(ctx, arguments)
	case "device.remove":
		return s.removeDevice(ctx, arguments.DeviceID)
	case "device.dismiss-pending":
		return s.dismissPendingDevice(ctx, arguments.DeviceID)
	case "device.remove-folder-shares":
		return s.removeDeviceFolderShares(ctx, arguments)
	case "lifecycle.start", "lifecycle.stop", "lifecycle.enable", "lifecycle.disable":
		return s.lifecycleAction(ctx, strings.TrimPrefix(action, "lifecycle."))
	case "webui.open":
		return s.openWebUI(ctx)
	case "webui.set-theme":
		return s.setWebUITheme(ctx, arguments.Theme)
	default:
		return rejected("unsupported_action", "action is not supported")
	}
}

func validateActionArguments(action string, arguments ActionArguments) *ActionResult {
	if arguments.CreateDirectory && action != "folder.add-existing" {
		result := rejected("invalid_action", "directory creation is only valid when adding a folder")
		return &result
	}
	folderOnly := arguments.FolderID != "" && arguments.Path == "" &&
		arguments.Label == "" && len(arguments.DeviceIDs) == 0 &&
		len(arguments.FolderIDs) == 0 &&
		arguments.PendingDeviceID == "" && arguments.DeviceID == "" &&
		arguments.DeviceName == "" && arguments.Theme == ""
	empty := arguments.FolderID == "" && arguments.Path == "" &&
		arguments.Label == "" && len(arguments.DeviceIDs) == 0 &&
		len(arguments.FolderIDs) == 0 &&
		arguments.PendingDeviceID == "" && arguments.DeviceID == "" &&
		arguments.DeviceName == "" && arguments.Theme == ""
	valid := false
	switch action {
	case "folder.pause", "folder.resume", "folder.rescan", "folder.forget":
		valid = folderOnly
	case "folder.recheck-errors", "folder.rescan-all", "folder.suggest-id",
		"lifecycle.start", "lifecycle.stop", "lifecycle.enable", "lifecycle.disable":
		valid = empty
	case "folder.add-existing":
		valid = arguments.Theme == "" && len(arguments.FolderIDs) == 0 &&
			arguments.DeviceID == "" &&
			arguments.DeviceName == ""
	case "folder.set-sharing":
		valid = arguments.FolderID != "" && arguments.Path == "" &&
			arguments.Label == "" && arguments.PendingDeviceID == "" &&
			arguments.DeviceID == "" && arguments.DeviceName == "" &&
			len(arguments.FolderIDs) == 0 && arguments.Theme == ""
	case "device.add":
		valid = arguments.DeviceID != "" && arguments.FolderID == "" &&
			arguments.Path == "" && arguments.Label == "" &&
			len(arguments.DeviceIDs) == 0 && arguments.PendingDeviceID == "" &&
			len(arguments.FolderIDs) == 0 && arguments.Theme == ""
	case "device.remove", "device.dismiss-pending":
		valid = arguments.DeviceID != "" && arguments.DeviceName == "" &&
			arguments.FolderID == "" && arguments.Path == "" &&
			arguments.Label == "" && len(arguments.DeviceIDs) == 0 &&
			len(arguments.FolderIDs) == 0 && arguments.PendingDeviceID == "" &&
			arguments.Theme == ""
	case "device.remove-folder-shares":
		valid = arguments.DeviceID != "" && arguments.DeviceName == "" &&
			arguments.FolderID == "" && arguments.Path == "" &&
			arguments.Label == "" && len(arguments.DeviceIDs) == 0 &&
			arguments.PendingDeviceID == "" && arguments.Theme == ""
	case "webui.set-theme":
		valid = arguments.Theme != "" && arguments.FolderID == "" && arguments.Path == "" &&
			arguments.Label == "" && len(arguments.DeviceIDs) == 0 &&
			len(arguments.FolderIDs) == 0 && arguments.PendingDeviceID == "" &&
			arguments.DeviceID == "" &&
			arguments.DeviceName == ""
	default:
		valid = empty
	}
	if valid {
		return nil
	}
	result := rejected("invalid_action", "action arguments are invalid")
	return &result
}

func (s *Session) setFolderPaused(ctx context.Context, folderID string, paused bool) ActionResult {
	snapshotFolder, currentFolder, result := s.verifiedFolder(ctx, folderID)
	if result.Error != nil {
		return result
	}
	if snapshotFolder.Paused != currentFolder.Paused {
		return rejected("folder_changed", "folder changed before the action")
	}
	if currentFolder.Paused == paused {
		if paused {
			return rejected("folder_paused", "folder is already paused")
		}
		return rejected("folder_active", "folder is already active")
	}
	if err := s.client.SetFolderPaused(ctx, folderID, paused); err != nil {
		return s.afterAmbiguousMutation(ctx, err)
	}
	return s.refreshAfterMutation(ctx)
}

func (s *Session) rescanFolder(ctx context.Context, folderID string) ActionResult {
	snapshotFolder, currentFolder, result := s.verifiedFolder(ctx, folderID)
	if result.Error != nil {
		return result
	}
	if snapshotFolder.Paused || currentFolder.Paused {
		return rejected("folder_paused", "paused folders cannot be rescanned")
	}
	disposition, requestErr := s.client.Rescan(ctx, folderID)
	published, refreshErr := s.Refresh(ctx)
	if requestErr != nil {
		return ActionResult{Error: publicError(requestErr)}
	}
	if refreshErr != nil {
		return ActionResult{Error: publicError(refreshErr)}
	}
	running := make([]string, 0, 1)
	if disposition == syncthing.RescanRunning && folderScanning(published.State, folderID) {
		running = append(running, folderID)
	}
	state := string(syncthing.RescanCompleted)
	if len(running) > 0 {
		state = string(syncthing.RescanRunning)
	}
	return ActionResult{OK: true, Data: RescanResult{State: state,
		TargetFolderIDs: []string{folderID}, RunningFolderIDs: running}}
}

type rescanAttempt struct {
	disposition syncthing.RescanDisposition
	err         error
}

func (s *Session) rescanAll(ctx context.Context) ActionResult {
	if result := s.requireOnline(); result != nil {
		return *result
	}
	folders, err := s.client.Folders(ctx)
	if err != nil {
		return ActionResult{Error: publicError(err)}
	}
	if len(folders) == 0 {
		return rejected("folder_missing", "no folders are configured")
	}
	if len(folders) > maxFolders {
		return rejected("folder_limit",
			"rescan all exceeds panel folder limits; use the Syncthing Web UI")
	}
	targets := make([]string, 0, len(folders))
	for _, folder := range folders {
		if !folder.Paused {
			targets = append(targets, folder.ID)
		}
	}
	sort.Strings(targets)
	if len(targets) == 0 {
		return rejected("folder_paused", "no linked folders are available to rescan")
	}
	attempts := make([]rescanAttempt, len(targets))
	if len(targets) == len(folders) {
		disposition, scanErr := s.client.Rescan(ctx, "")
		for index := range attempts {
			attempts[index] = rescanAttempt{disposition: disposition, err: scanErr}
		}
	} else {
		s.rescanTargets(ctx, targets, attempts)
	}
	published, refreshErr := s.Refresh(ctx)
	for index := range attempts {
		if attempts[index].err != nil {
			return ActionResult{Error: publicError(attempts[index].err)}
		}
	}
	if refreshErr != nil {
		return ActionResult{Error: publicError(refreshErr)}
	}
	for index, folderID := range targets {
		if attempts[index].disposition == syncthing.RescanRunning &&
			findFolder(published.State.Folders, folderID) == nil {
			return rejected("folder_changed",
				"rescan completion cannot be confirmed; use the Syncthing Web UI")
		}
	}
	return ActionResult{OK: true, Data: rescanResult(targets, attempts, published.State)}
}

func (s *Session) rescanTargets(
	ctx context.Context,
	targets []string,
	attempts []rescanAttempt,
) {
	jobs := make(chan int)
	workers := min(rescanAllWorkers, len(targets))
	var wait sync.WaitGroup
	wait.Add(workers)
	for range workers {
		go func() {
			defer wait.Done()
			for index := range jobs {
				disposition, err := s.client.Rescan(ctx, targets[index])
				attempts[index] = rescanAttempt{disposition: disposition, err: err}
			}
		}()
	}
	for index := range targets {
		jobs <- index
	}
	close(jobs)
	wait.Wait()
}

func folderScanning(snapshot Snapshot, folderID string) bool {
	folder := findFolder(snapshot.Folders, folderID)
	return folder != nil && strings.HasPrefix(folder.Status.State, "scan")
}

func rescanResult(targets []string, attempts []rescanAttempt, snapshot Snapshot) RescanResult {
	running := make([]string, 0, len(targets))
	for index, folderID := range targets {
		if attempts[index].disposition == syncthing.RescanRunning &&
			folderScanning(snapshot, folderID) {
			running = append(running, folderID)
		}
	}
	state := string(syncthing.RescanCompleted)
	if len(running) > 0 {
		state = string(syncthing.RescanRunning)
	}
	return RescanResult{State: state, TargetFolderIDs: targets,
		RunningFolderIDs: running}
}

func (s *Session) recheckFolderErrors(ctx context.Context) ActionResult {
	if result := s.requireOnline(); result != nil {
		return *result
	}
	var firstErr error
	for _, folder := range s.Current().State.Folders {
		status := folder.Status
		if folder.Paused || status.Error == "" && status.PullErrors == 0 &&
			len(status.Errors) == 0 {
			continue
		}
		if _, err := s.client.Rescan(ctx, folder.ID); err != nil && firstErr == nil {
			firstErr = err
		}
	}
	_, refreshErr := s.Refresh(ctx)
	if refreshErr != nil {
		return ActionResult{Error: publicError(refreshErr)}
	}
	if firstErr != nil {
		return ActionResult{Error: publicError(firstErr)}
	}
	return ActionResult{OK: true}
}

func (s *Session) forgetFolder(ctx context.Context, folderID string) ActionResult {
	snapshotFolder, currentFolder, result := s.verifiedFolder(ctx, folderID)
	if result.Error != nil {
		return result
	}
	if !snapshotFolder.Paused || !currentFolder.Paused {
		return rejected("folder_active", "folder must be paused before it is forgotten")
	}
	if err := s.client.DeleteFolder(ctx, folderID); err != nil {
		return s.afterAmbiguousMutation(ctx, err)
	}
	return s.refreshAfterMutation(ctx)
}

func (s *Session) addExistingFolder(ctx context.Context, arguments ActionArguments) ActionResult {
	if result := s.requireOnline(); result != nil {
		return *result
	}
	folderID := strings.TrimSpace(arguments.FolderID)
	if folderID == "" || len(folderID) > 128 || !safeName.MatchString(folderID) {
		return rejected("folder_id_invalid", "folder ID is invalid")
	}
	canonicalPath, validation := canonicalDirectory(arguments.Path)
	missing := validation != nil && validation.Error.Code == "path_missing"
	if validation != nil && !(missing && arguments.CreateDirectory) {
		return *validation
	}
	folders, err := s.client.Folders(ctx)
	if err != nil {
		return ActionResult{Error: publicError(err)}
	}
	status, err := s.client.Status(ctx)
	if err != nil {
		return ActionResult{Error: publicError(err)}
	}
	if result := validateUnusedFolder(folderID, canonicalPath, folders, status.Tilde); result != nil {
		return *result
	}
	devices, err := s.client.Devices(ctx)
	if err != nil {
		return ActionResult{Error: publicError(err)}
	}
	pending, err := s.client.PendingFolders(ctx)
	if err != nil {
		return ActionResult{Error: publicError(err)}
	}
	localID := s.Current().State.Identity.DeviceID
	selected, validation := validateSelectedDevices(arguments, devices, pending, localID)
	if validation != nil {
		return *validation
	}
	defaults, err := s.client.DefaultFolder(ctx)
	if err != nil {
		return ActionResult{Error: publicError(err)}
	}
	label := strings.TrimSpace(arguments.Label)
	if label == "" && arguments.PendingDeviceID != "" {
		label = pending[folderID].OfferedBy[arguments.PendingDeviceID].Label
	}
	if label == "" {
		label = filepath.Base(canonicalPath)
	}
	defaults["id"] = folderID
	defaults["label"] = boundedLabel(label)
	defaults["path"] = canonicalPath
	defaults["paused"] = false
	defaults["devices"] = selectFolderDevices(nil,
		append([]string{localID}, selected...))
	if missing {
		if err := os.MkdirAll(canonicalPath, 0o755); err != nil {
			return rejected("path_create_failed", "cannot create folder directory: "+err.Error())
		}
		canonicalPath, validation = canonicalDirectory(canonicalPath)
		if validation != nil {
			return *validation
		}
		if result := validateUnusedFolder(folderID, canonicalPath, folders, status.Tilde); result != nil {
			return *result
		}
		defaults["path"] = canonicalPath
	}
	if err := s.client.AddFolder(ctx, defaults); err != nil {
		return s.afterAmbiguousMutation(ctx, err)
	}
	result := s.refreshAfterMutation(ctx)
	result.Data = map[string]string{"folderId": folderID}
	return result
}

func (s *Session) suggestFolderID(ctx context.Context) ActionResult {
	if result := s.requireOnline(); result != nil {
		return *result
	}
	suggestion, err := s.client.RandomString(ctx, 10)
	if err != nil {
		return ActionResult{Error: publicError(err)}
	}
	suggestion = strings.ToLower(strings.TrimSpace(suggestion))
	if len(suggestion) != 10 || !safeName.MatchString(suggestion) {
		return rejected("suggestion_invalid", "Syncthing returned an invalid folder ID")
	}
	return ActionResult{OK: true,
		Data: map[string]string{"folderId": suggestion}}
}

func (s *Session) setWebUITheme(ctx context.Context, theme string) ActionResult {
	if result := s.requireOnline(); result != nil {
		return *result
	}
	theme = strings.TrimSpace(theme)
	if theme == "" || len(theme) > 64 || !safeName.MatchString(theme) {
		return rejected("theme_invalid", "Web UI theme name is invalid")
	}
	setErr := s.client.SetGUITheme(ctx, theme)
	if setErr != nil && !ambiguousMutation(setErr) {
		return ActionResult{Error: publicError(setErr)}
	}
	for attempt := 0; attempt < 6; attempt++ {
		gui, err := s.client.GUIConfig(ctx)
		if err == nil && gui.Theme == theme {
			return s.refreshAfterMutation(ctx)
		}
		select {
		case <-ctx.Done():
			return rejected("canceled", "theme verification was canceled")
		case <-time.After(time.Duration(attempt+1) * 100 * time.Millisecond):
		}
	}
	return rejected("theme_unverified", "Syncthing did not retain the requested Web UI theme")
}

func (s *Session) verifiedFolder(
	ctx context.Context,
	folderID string,
) (*Folder, syncthing.Folder, ActionResult) {
	if result := s.requireOnline(); result != nil {
		return nil, syncthing.Folder{}, *result
	}
	folderID = strings.TrimSpace(folderID)
	snapshotFolder := findFolder(s.Current().State.Folders, folderID)
	if snapshotFolder == nil {
		return nil, syncthing.Folder{}, rejected("folder_missing", "folder is no longer configured")
	}
	current, err := s.client.Folder(ctx, folderID)
	if err != nil {
		return nil, syncthing.Folder{}, ActionResult{Error: publicError(err)}
	}
	if current.ID != snapshotFolder.ID || current.Path != snapshotFolder.Path {
		return nil, syncthing.Folder{}, rejected("folder_changed", "folder changed before the action")
	}
	return snapshotFolder, current, ActionResult{}
}

func (s *Session) requireOnline() *ActionResult {
	if s.Current().State.Connection.Online {
		return nil
	}
	result := rejected("offline", "Syncthing is not online")
	return &result
}

func (s *Session) refreshAfterMutation(ctx context.Context) ActionResult {
	_, err := s.Refresh(ctx)
	if err != nil {
		return ActionResult{Error: publicError(err)}
	}
	return ActionResult{OK: true}
}

func (s *Session) afterAmbiguousMutation(ctx context.Context, err error) ActionResult {
	if ambiguousMutation(err) {
		_, _ = s.Refresh(ctx)
		return ActionResult{Error: publicError(err)}
	}
	return ActionResult{Error: publicError(err)}
}

func ambiguousMutation(err error) bool {
	var target *syncthing.Error
	return errors.As(err, &target) &&
		(target.Code == syncthing.ErrorConnection || target.Code == syncthing.ErrorTimeout)
}

func findFolder(folders []Folder, folderID string) *Folder {
	for index := range folders {
		if folders[index].ID == folderID {
			copy := folders[index]
			return &copy
		}
	}
	return nil
}

func canonicalDirectory(path string) (string, *ActionResult) {
	path = strings.TrimSpace(path)
	if !filepath.IsAbs(path) {
		result := rejected("path_invalid", "folder path must be absolute")
		return "", &result
	}
	path = filepath.Clean(path)
	existing := path
	var missing []string
	for {
		_, err := os.Lstat(existing)
		if err == nil {
			break
		}
		if !errors.Is(err, os.ErrNotExist) {
			result := rejected("path_unavailable", "cannot access folder path: "+err.Error())
			return "", &result
		}
		parent := filepath.Dir(existing)
		if parent == existing {
			result := rejected("path_unavailable", "cannot access the filesystem root")
			return "", &result
		}
		missing = append(missing, filepath.Base(existing))
		existing = parent
	}
	resolved, err := filepath.EvalSymlinks(existing)
	if err != nil {
		result := rejected("path_unavailable", "cannot resolve folder path or symlink: "+err.Error())
		return "", &result
	}
	info, err := os.Stat(resolved)
	if err != nil {
		result := rejected("path_unavailable", "cannot access folder path: "+err.Error())
		return "", &result
	}
	if !info.IsDir() {
		result := rejected("path_invalid", "folder path is not a directory")
		return "", &result
	}
	for i := len(missing) - 1; i >= 0; i-- {
		resolved = filepath.Join(resolved, missing[i])
	}
	if len(missing) > 0 {
		result := rejected("path_missing", "folder path does not exist")
		return resolved, &result
	}
	return resolved, nil
}

func validateUnusedFolder(folderID, path string, folders []syncthing.Folder, home string) *ActionResult {
	for _, folder := range folders {
		if folder.ID == folderID {
			result := rejected("folder_exists", "folder ID is already configured")
			return &result
		}
		configured := filepath.Clean(folder.Path)
		if (configured == "~" || strings.HasPrefix(configured, "~/")) && filepath.IsAbs(home) {
			configured = filepath.Join(home, strings.TrimPrefix(configured, "~"))
		}
		if !filepath.IsAbs(configured) {
			result := rejected("path_unresolved",
				"cannot check folder overlap; set existing relative folder paths to absolute paths in Syncthing")
			return &result
		}
		if resolved, err := filepath.EvalSymlinks(configured); err == nil {
			configured = resolved
		}
		if pathsOverlap(path, configured) {
			result := rejected("path_overlap", "folder path overlaps an existing folder")
			return &result
		}
	}
	return nil
}

func pathsOverlap(first, second string) bool {
	for _, pair := range [][2]string{{first, second}, {second, first}} {
		relative, err := filepath.Rel(pair[0], pair[1])
		if err == nil && relative != ".." && !strings.HasPrefix(relative, ".."+string(os.PathSeparator)) {
			return true
		}
	}
	return false
}

func validateSelectedDevices(
	arguments ActionArguments,
	devices []syncthing.Device,
	pending syncthing.PendingFolders,
	localID string,
) ([]string, *ActionResult) {
	selected, validation := validateRemoteDevices(arguments.DeviceIDs, devices, localID)
	if validation != nil {
		return nil, validation
	}
	selectedSet := make(map[string]struct{}, len(selected))
	for _, deviceID := range selected {
		selectedSet[deviceID] = struct{}{}
	}
	if arguments.PendingDeviceID != "" {
		offer, exists := pending[arguments.FolderID].OfferedBy[arguments.PendingDeviceID]
		if !exists {
			result := rejected("offer_missing", "selected folder offer is no longer available")
			return nil, &result
		}
		if offer.ReceiveEncrypted || offer.RemoteEncrypted {
			result := rejected("offer_encrypted", "encrypted folder offers are unsupported")
			return nil, &result
		}
		if _, selected := selectedSet[arguments.PendingDeviceID]; !selected {
			result := rejected("offer_device_missing", "offering device must remain selected")
			return nil, &result
		}
	}
	return selected, nil
}
