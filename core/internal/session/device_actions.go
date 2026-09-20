package session

import (
	"context"
	"regexp"
	"sort"
	"strings"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
)

var deviceIDPattern = regexp.MustCompile(`^[A-Z2-7]{7}(-[A-Z2-7]{7}){7}$`)

type folderDevicePatch struct {
	folderID string
	devices  []syncthing.FolderDevice
}

func (s *Session) setDeviceFolders(ctx context.Context, arguments ActionArguments) ActionResult {
	if result := s.requireOnline(); result != nil {
		return *result
	}
	deviceID := strings.TrimSpace(arguments.DeviceID)
	current := s.Current().State
	configured := false
	sharedFolderIDs := make(map[string]struct{})
	for _, device := range current.Devices {
		if device.ID == deviceID && device.ID != current.Identity.DeviceID && !device.Untrusted {
			configured = true
			break
		}
	}
	if !configured {
		return rejected("device_invalid", "remote device is unavailable or untrusted")
	}
	for _, folder := range current.Folders {
		for _, member := range folder.Devices {
			if member.ID == deviceID {
				sharedFolderIDs[folder.ID] = struct{}{}
				break
			}
		}
	}
	wanted := make(map[string]struct{}, len(arguments.FolderIDs))
	for _, rawID := range arguments.FolderIDs {
		folderID := strings.TrimSpace(rawID)
		if _, shared := sharedFolderIDs[folderID]; !shared {
			return rejected("folder_add_unsupported",
				"device folder view can only remove existing shares")
		}
		wanted[folderID] = struct{}{}
	}
	patches := make([]folderDevicePatch, 0, len(sharedFolderIDs)-len(wanted))
	for _, folder := range current.Folders {
		if _, shared := sharedFolderIDs[folder.ID]; !shared {
			continue
		}
		if _, keep := wanted[folder.ID]; keep {
			continue
		}
		config, err := s.client.Folder(ctx, folder.ID)
		if err != nil {
			return ActionResult{Error: publicError(err)}
		}
		next := make([]syncthing.FolderDevice, 0, len(config.Devices))
		for _, member := range config.Devices {
			if member.DeviceID != deviceID {
				next = append(next, member)
			}
		}
		if len(next) != len(config.Devices) {
			patches = append(patches, folderDevicePatch{folderID: folder.ID, devices: next})
		}
	}
	for _, patch := range patches {
		if err := s.client.SetFolderDevices(ctx, patch.folderID, patch.devices); err != nil {
			return s.afterAmbiguousMutation(ctx, err)
		}
	}
	return s.refreshAfterMutation(ctx)
}

func (s *Session) setFolderSharing(ctx context.Context, arguments ActionArguments) ActionResult {
	if result := s.requireOnline(); result != nil {
		return *result
	}
	folderID := strings.TrimSpace(arguments.FolderID)
	if findFolder(s.Current().State.Folders, folderID) == nil {
		return rejected("folder_missing", "folder is no longer configured")
	}
	devices, err := s.client.Devices(ctx)
	if err != nil {
		return ActionResult{Error: publicError(err)}
	}
	localID := s.Current().State.Identity.DeviceID
	selected, validation := validateRemoteDevices(arguments.DeviceIDs, devices, localID)
	if validation != nil {
		return *validation
	}
	config, err := s.client.Folder(ctx, folderID)
	if err != nil {
		return ActionResult{Error: publicError(err)}
	}
	wanted := make(map[string]struct{}, len(selected)+1)
	wanted[localID] = struct{}{}
	for _, id := range selected {
		wanted[id] = struct{}{}
	}
	next := make([]syncthing.FolderDevice, 0, len(wanted))
	seen := make(map[string]struct{}, len(wanted))
	for _, device := range config.Devices {
		id := device.DeviceID
		if _, keep := wanted[id]; keep {
			next = append(next, device)
			seen[id] = struct{}{}
		}
	}
	for _, id := range append([]string{localID}, selected...) {
		if _, exists := seen[id]; !exists {
			next = append(next, syncthing.NewFolderDevice(id))
		}
	}
	if err := s.client.SetFolderDevices(ctx, folderID, next); err != nil {
		return s.afterAmbiguousMutation(ctx, err)
	}
	return s.refreshAfterMutation(ctx)
}

func (s *Session) addDevice(ctx context.Context, arguments ActionArguments) ActionResult {
	if result := s.requireOnline(); result != nil {
		return *result
	}
	deviceID := strings.ToUpper(strings.TrimSpace(arguments.DeviceID))
	if !deviceIDPattern.MatchString(deviceID) {
		return rejected("device_id_invalid", "device ID is invalid")
	}
	current := s.Current().State
	if deviceID == current.Identity.DeviceID {
		return rejected("device_self", "this device cannot be added as a remote device")
	}
	devices, err := s.client.Devices(ctx)
	if err != nil {
		return ActionResult{Error: publicError(err)}
	}
	for _, device := range devices {
		if device.DeviceID == deviceID {
			return rejected("device_exists", "device is already configured")
		}
	}
	name := strings.TrimSpace(arguments.DeviceName)
	if len(name) > maxLabel {
		return rejected("device_name_invalid", "device name is too long")
	}
	defaults, err := s.client.DefaultDevice(ctx)
	if err != nil {
		return ActionResult{Error: publicError(err)}
	}
	defaults["deviceID"] = deviceID
	if name != "" {
		defaults["name"] = name
	}
	if err := s.client.AddDevice(ctx, defaults); err != nil {
		return s.afterAmbiguousMutation(ctx, err)
	}
	return s.refreshAfterMutation(ctx)
}

func (s *Session) dismissPendingDevice(ctx context.Context, rawDeviceID string) ActionResult {
	if result := s.requireOnline(); result != nil {
		return *result
	}
	deviceID := strings.ToUpper(strings.TrimSpace(rawDeviceID))
	pending, err := s.client.PendingDevices(ctx)
	if err != nil {
		return ActionResult{Error: publicError(err)}
	}
	if _, exists := pending[deviceID]; !exists {
		return rejected("pending_device_missing", "pending device is no longer available")
	}
	if err := s.client.DismissPendingDevice(ctx, deviceID); err != nil {
		return s.afterAmbiguousMutation(ctx, err)
	}
	return s.refreshAfterMutation(ctx)
}

func validateRemoteDevices(
	deviceIDs []string,
	devices []syncthing.Device,
	localID string,
) ([]string, *ActionResult) {
	available := make(map[string]syncthing.Device, len(devices))
	for _, device := range devices {
		available[device.DeviceID] = device
	}
	selectedSet := make(map[string]struct{}, len(deviceIDs))
	for _, rawID := range deviceIDs {
		deviceID := strings.TrimSpace(rawID)
		device, exists := available[deviceID]
		if !exists || device.Untrusted || deviceID == localID {
			result := rejected("device_invalid", "selected remote device is unavailable or untrusted")
			return nil, &result
		}
		selectedSet[deviceID] = struct{}{}
	}
	selected := make([]string, 0, len(selectedSet))
	for deviceID := range selectedSet {
		selected = append(selected, deviceID)
	}
	sort.Strings(selected)
	return selected, nil
}
