package syncthing

import (
	"context"
	"encoding/json"
	"net/http"
	"net/url"
	"strconv"
)

// Folder reads one current folder configuration.
func (c *Client) Folder(ctx context.Context, folderID string) (Folder, error) {
	var response Folder
	path := "/rest/config/folders/" + url.PathEscape(folderID)
	err := c.request(ctx, http.MethodGet, path, nil, true, &response)
	return response, err
}

// SetFolderPaused changes only one folder's pause state.
func (c *Client) SetFolderPaused(ctx context.Context, folderID string, paused bool) error {
	return c.jsonRequest(ctx, http.MethodPatch,
		"/rest/config/folders/"+url.PathEscape(folderID),
		map[string]bool{"paused": paused}, nil)
}

// SetFolderDevices replaces one folder's sharing relationships.
func (c *Client) SetFolderDevices(
	ctx context.Context,
	folderID string,
	devices []FolderDevice,
) error {
	patch := struct {
		Devices []FolderDevice `json:"devices"`
	}{Devices: devices}
	return c.jsonRequest(ctx, http.MethodPatch,
		"/rest/config/folders/"+url.PathEscape(folderID), patch, nil)
}

// DeleteFolder removes only the Syncthing folder record.
func (c *Client) DeleteFolder(ctx context.Context, folderID string) error {
	return c.request(ctx, http.MethodDelete,
		"/rest/config/folders/"+url.PathEscape(folderID), nil, true, nil)
}

// DefaultFolder reads the server's complete current folder template.
func (c *Client) DefaultFolder(ctx context.Context) (FolderConfig, error) {
	var response FolderConfig
	err := c.request(ctx, http.MethodGet, "/rest/config/defaults/folder", nil, true, &response)
	return response, err
}

// AddFolder posts one configuration built from the server default.
func (c *Client) AddFolder(ctx context.Context, config FolderConfig) error {
	return c.jsonRequest(ctx, http.MethodPost, "/rest/config/folders", config, nil)
}

// DefaultDevice reads the server's complete current device template.
func (c *Client) DefaultDevice(ctx context.Context) (DeviceConfig, error) {
	var response DeviceConfig
	err := c.request(ctx, http.MethodGet, "/rest/config/defaults/device", nil, true, &response)
	return response, err
}

// AddDevice posts one configuration built from the server default.
func (c *Client) AddDevice(ctx context.Context, config DeviceConfig) error {
	return c.jsonRequest(ctx, http.MethodPost, "/rest/config/devices", config, nil)
}

// DeleteDevice removes one device from the local configuration.
func (c *Client) DeleteDevice(ctx context.Context, deviceID string) error {
	return c.request(ctx, http.MethodDelete,
		"/rest/config/devices/"+url.PathEscape(deviceID), nil, true, nil)
}

// PendingDevices reads current unknown-device connection attempts.
func (c *Client) PendingDevices(ctx context.Context) (PendingDevices, error) {
	var response PendingDevices
	err := c.request(ctx, http.MethodGet,
		"/rest/cluster/pending/devices", nil, true, &response)
	return response, err
}

// DismissPendingDevice removes one unknown-device connection attempt.
func (c *Client) DismissPendingDevice(ctx context.Context, deviceID string) error {
	path := "/rest/cluster/pending/devices?device=" + url.QueryEscape(deviceID)
	return c.request(ctx, http.MethodDelete, path, nil, true, nil)
}

// DiscoveryCache reads Syncthing's current local and global discovery cache.
func (c *Client) DiscoveryCache(ctx context.Context) (DiscoveryCache, error) {
	var response DiscoveryCache
	err := c.request(ctx, http.MethodGet,
		"/rest/system/discovery", nil, true, &response)
	return response, err
}

// PendingFolders reads current unaccepted offers.
func (c *Client) PendingFolders(ctx context.Context) (PendingFolders, error) {
	var response PendingFolders
	err := c.request(ctx, http.MethodGet, "/rest/cluster/pending/folders", nil, true, &response)
	return response, err
}

// GUIConfig reads the current Syncthing GUI theme.
func (c *Client) GUIConfig(ctx context.Context) (GUIConfig, error) {
	var response GUIConfig
	err := c.request(ctx, http.MethodGet, "/rest/config/gui", nil, true, &response)
	return response, err
}

// SetGUITheme changes only the current Syncthing GUI theme.
func (c *Client) SetGUITheme(ctx context.Context, theme string) error {
	return c.jsonRequest(ctx, http.MethodPatch, "/rest/config/gui",
		map[string]string{"theme": theme}, nil)
}

// SystemPaths reads host-neutral runtime paths reported by Syncthing.
func (c *Client) SystemPaths(ctx context.Context) (SystemPaths, error) {
	var response SystemPaths
	err := c.request(ctx, http.MethodGet, "/rest/system/paths", nil, true, &response)
	return response, err
}

// FolderErrors reads current scan and pull errors.
func (c *Client) FolderErrors(ctx context.Context, folderID string) (FolderErrors, error) {
	var response FolderErrors
	path := "/rest/folder/errors?folder=" + url.QueryEscape(folderID) + "&page=1&perpage=100"
	err := c.request(ctx, http.MethodGet, path, nil, true, &response)
	// A new folder can be configured before its model is ready for this endpoint.
	if hasHTTPStatus(err, http.StatusNotFound) {
		return FolderErrors{}, nil
	}
	return response, err
}

// RandomString requests one strong folder-ID suggestion.
func (c *Client) RandomString(ctx context.Context, length int) (string, error) {
	var response RandomString
	path := "/rest/svc/random/string?length=" + strconv.Itoa(length)
	err := c.request(ctx, http.MethodGet, path, nil, true, &response)
	return response.Random, err
}

// FileInfo reads current local state for an indexed path.
func (c *Client) FileInfo(ctx context.Context, folderID, name string) (FileInfo, error) {
	var response FileInfo
	path := "/rest/db/file?folder=" + url.QueryEscape(folderID) +
		"&file=" + url.QueryEscape(name)
	err := c.request(ctx, http.MethodGet, path, nil, true, &response)
	return response, err
}

// RescanSubdirectory requests a narrow directory scan.
func (c *Client) RescanSubdirectory(ctx context.Context, folderID, subdirectory string) error {
	path := "/rest/db/scan?folder=" + url.QueryEscape(folderID) +
		"&sub=" + url.QueryEscape(subdirectory)
	return c.request(ctx, http.MethodPost, path, nil, true, nil)
}

func (c *Client) jsonRequest(
	ctx context.Context,
	method string,
	path string,
	value any,
	destination any,
) error {
	body, err := json.Marshal(value)
	if err != nil {
		return failure(ErrorSchema, "request", "could not encode Syncthing request", err)
	}
	return c.request(ctx, method, path, body, true, destination)
}
