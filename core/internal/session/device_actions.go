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

func (s *Session) removeDeviceFolderShares(
	ctx context.Context,
	arguments ActionArguments,
) ActionResult {
	if result := s.requireOnline(); result != nil {
		return *result
	}
	deviceID := strings.TrimSpace(arguments.DeviceID)
	current := s.Current().State
	configured := false
	for _, device := range current.Devices {
		if device.ID == deviceID && device.ID != current.Identity.DeviceID {
			configured = true
			break
		}
	}
	if !configured {
		return rejected("device_invalid", "remote device is unavailable")
	}
	requested := make(map[string]struct{}, len(arguments.FolderIDs))
	for _, rawID := range arguments.FolderIDs {
		folderID := strings.TrimSpace(rawID)
		if folderID == "" {
			return rejected("folder_share_missing", "folder share is unavailable")
		}
		requested[folderID] = struct{}{}
	}
	patches := make([]folderDevicePatch, 0, len(requested))
	for _, folder := range current.Folders {
		if _, remove := requested[folder.ID]; !remove {
			continue
		}
		shared := false
		for _, member := range folder.Devices {
			if member.ID == deviceID {
				shared = true
				break
			}
		}
		if !shared {
			return rejected("folder_share_missing", "folder is not shared with this device")
		}
		_, config, result := s.verifiedFolder(ctx, folder.ID)
		if result.Error != nil {
			return result
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
		delete(requested, folder.ID)
	}
	if len(requested) > 0 {
		return rejected("folder_share_missing", "folder share is unavailable")
	}
	return s.applyFolderDevicePatches(ctx, patches)
}

func (s *Session) setFolderSharing(ctx context.Context, arguments ActionArguments) ActionResult {
	folderID := strings.TrimSpace(arguments.FolderID)
	_, config, result := s.verifiedFolder(ctx, folderID)
	if result.Error != nil {
		return result
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
	next := selectFolderDevices(config.Devices,
		append([]string{localID}, selected...))
	return s.applyFolderDevicePatches(ctx, []folderDevicePatch{{
		folderID: folderID,
		devices:  next,
	}})
}

func (s *Session) applyFolderDevicePatches(
	ctx context.Context,
	patches []folderDevicePatch,
) ActionResult {
	wrote := false
	for _, patch := range patches {
		if err := s.client.SetFolderDevices(ctx, patch.folderID, patch.devices); err != nil {
			if wrote && !ambiguousMutation(err) {
				_, _ = s.Refresh(ctx)
				return ActionResult{Error: publicError(err)}
			}
			return s.afterAmbiguousMutation(ctx, err)
		}
		wrote = true
	}
	return s.refreshAfterMutation(ctx)
}

func selectFolderDevices(
	existing []syncthing.FolderDevice,
	wantedIDs []string,
) []syncthing.FolderDevice {
	wanted := make(map[string]struct{}, len(wantedIDs))
	ordered := make([]string, 0, len(wantedIDs))
	for _, rawID := range wantedIDs {
		deviceID := strings.TrimSpace(rawID)
		if deviceID == "" {
			continue
		}
		if _, exists := wanted[deviceID]; exists {
			continue
		}
		wanted[deviceID] = struct{}{}
		ordered = append(ordered, deviceID)
	}
	result := make([]syncthing.FolderDevice, 0, len(wanted))
	seen := make(map[string]struct{}, len(wanted))
	for _, device := range existing {
		if _, keep := wanted[device.DeviceID]; !keep {
			continue
		}
		if _, duplicate := seen[device.DeviceID]; duplicate {
			continue
		}
		result = append(result, device)
		seen[device.DeviceID] = struct{}{}
	}
	for _, deviceID := range ordered {
		if _, exists := seen[deviceID]; exists {
			continue
		}
		result = append(result, syncthing.NewFolderDevice(deviceID))
	}
	return result
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
