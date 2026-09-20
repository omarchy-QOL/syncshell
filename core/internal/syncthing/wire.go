package syncthing

import (
	"encoding/json"
	"errors"
)

// SystemStatus is the narrow identity response used by the session.
type SystemStatus struct {
	MyID  string `json:"myID"`
	Tilde string `json:"tilde"`
}

// SystemVersion is the narrow version response used by the session.
type SystemVersion struct {
	Version string `json:"version"`
}

// Device is the configured-device wire shape used by the client.
type Device struct {
	DeviceID  string `json:"deviceID"`
	Name      string `json:"name"`
	Untrusted bool   `json:"untrusted"`
}

// FolderDevice is a folder-sharing relationship that preserves server fields.
type FolderDevice struct {
	DeviceID string `json:"deviceID"`
	fields   map[string]json.RawMessage
}

// NewFolderDevice constructs a folder-sharing relationship.
func NewFolderDevice(deviceID string) FolderDevice {
	return FolderDevice{DeviceID: deviceID}
}

// UnmarshalJSON preserves fields Syncshell does not interpret.
func (d *FolderDevice) UnmarshalJSON(data []byte) error {
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(data, &fields); err != nil {
		return err
	}
	var deviceID string
	value, ok := fields["deviceID"]
	if !ok || json.Unmarshal(value, &deviceID) != nil || deviceID == "" {
		return errors.New("folder device ID is invalid")
	}
	d.DeviceID = deviceID
	d.fields = fields
	return nil
}

// MarshalJSON restores preserved fields with the current device ID.
func (d FolderDevice) MarshalJSON() ([]byte, error) {
	if d.DeviceID == "" {
		return nil, errors.New("folder device ID is invalid")
	}
	fields := make(map[string]json.RawMessage, len(d.fields)+1)
	for name, value := range d.fields {
		fields[name] = value
	}
	deviceID, err := json.Marshal(d.DeviceID)
	if err != nil {
		return nil, err
	}
	fields["deviceID"] = deviceID
	return json.Marshal(fields)
}

// Folder is the configured-folder wire shape used by the client.
type Folder struct {
	ID         string         `json:"id"`
	Label      string         `json:"label"`
	Path       string         `json:"path"`
	Paused     bool           `json:"paused"`
	MarkerName string         `json:"markerName"`
	Devices    []FolderDevice `json:"devices"`
}

// FolderStatus is the bounded database status used by the session.
type FolderStatus struct {
	State          string `json:"state"`
	Error          string `json:"error"`
	PullErrors     int    `json:"pullErrors"`
	NeedTotalItems int    `json:"needTotalItems"`
	NeedBytes      int64  `json:"needBytes"`
	GlobalFiles    int    `json:"globalFiles"`
	GlobalBytes    int64  `json:"globalBytes"`
}

// Connections is the configured connection response.
type Connections struct {
	Connections map[string]Connection `json:"connections"`
}

// Connection contains only the fields needed for aggregate state.
type Connection struct {
	Connected bool `json:"connected"`
}

// PendingFolders maps offered folder IDs to their offering devices.
type PendingFolders map[string]PendingFolder

// PendingDevices maps unknown device IDs to their latest connection attempt.
type PendingDevices map[string]PendingDevice

// PendingDevice is one unknown device observed by Syncthing.
type PendingDevice struct {
	Name    string `json:"name"`
	Address string `json:"address"`
}

// DiscoveryCache maps discovered device IDs to their observed addresses.
type DiscoveryCache map[string]DiscoveryEntry

// DiscoveryEntry is one local or global discovery result.
type DiscoveryEntry struct {
	Addresses []string `json:"addresses"`
}

// PendingFolder is one unaccepted folder offer.
type PendingFolder struct {
	OfferedBy map[string]FolderOffer `json:"offeredBy"`
}

// FolderOffer contains the safety-relevant pending-offer fields.
type FolderOffer struct {
	Label            string `json:"label"`
	ReceiveEncrypted bool   `json:"receiveEncrypted"`
	RemoteEncrypted  bool   `json:"remoteEncrypted"`
}

// GUIConfig contains the host-neutral Syncthing GUI state.
type GUIConfig struct {
	Theme string `json:"theme"`
}

// SystemPaths contains only paths required by current host workflows.
type SystemPaths struct {
	GUIAssets string `json:"guiAssets"`
	Config    string `json:"config"`
}

// FolderErrors is the current bounded folder error response.
type FolderErrors struct {
	Errors []FolderError `json:"errors"`
}

// FolderError is one current scan or pull error.
type FolderError struct {
	Path  string `json:"path"`
	Error string `json:"error"`
}

// RandomString is a strong server-generated identifier response.
type RandomString struct {
	Random string `json:"random"`
}

// FileInfo is the current local file information used for activity.
type FileInfo struct {
	Local  *FileEntry `json:"local"`
	Global *FileEntry `json:"global"`
}

// FileEntry is the narrow file state required for activity classification.
type FileEntry struct {
	Name    string `json:"name"`
	Type    any    `json:"type"`
	Deleted bool   `json:"deleted"`
}

// Event is the bounded Event API wire envelope.
type Event struct {
	ID   int64           `json:"id"`
	Type string          `json:"type"`
	Data json.RawMessage `json:"data"`
}

// FolderConfig preserves the server's current default folder fields.
type FolderConfig map[string]any

// DeviceConfig preserves the server's current default device fields.
type DeviceConfig map[string]any
