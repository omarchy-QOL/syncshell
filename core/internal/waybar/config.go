package waybar

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"

	"github.com/omarchy-QOL/syncshell/core/internal/session"
)

// loadConfig leaves endpoint and credential validation to shared discovery.
func loadConfig(path string) (session.Config, error) {
	config := session.Config{ReadOnly: true}
	optional := path == ""
	if optional {
		dir, err := os.UserConfigDir()
		if err != nil {
			return config, errors.New("cannot locate user configuration")
		}
		path = filepath.Join(dir, "syncshell", "waybar.json")
	}
	f, err := os.Open(path)
	if optional && errors.Is(err, os.ErrNotExist) {
		return config, nil
	}
	if err != nil {
		return config, errors.New("cannot read Waybar configuration")
	}
	defer f.Close()
	var values *struct {
		SyncthingConfig  string `json:"syncthing_config"`
		Endpoint         string `json:"endpoint"`
		CredentialFile   string `json:"api_key_file"`
		TLSCertificate   string `json:"tls_certificate"`
		ExpectedDeviceID string `json:"expected_device_id"`
	}
	contents, err := io.ReadAll(io.LimitReader(f, (64<<10)+1))
	if err != nil || len(contents) > 64<<10 {
		return config, errors.New("invalid Waybar configuration")
	}
	decoder := json.NewDecoder(bytes.NewReader(contents))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&values); err != nil || values == nil {
		return config, errors.New("invalid Waybar configuration")
	}
	var extra any
	if decoder.Decode(&extra) != io.EOF {
		return config, errors.New("invalid Waybar configuration")
	}
	for _, path := range []string{values.SyncthingConfig, values.CredentialFile, values.TLSCertificate} {
		if path != "" && !filepath.IsAbs(path) {
			return config, errors.New("configuration paths must be absolute")
		}
	}
	if values.SyncthingConfig != "" && (values.Endpoint != "" || values.CredentialFile != "" || values.TLSCertificate != "") {
		return config, errors.New("select a Syncthing config or an endpoint, not both")
	}
	if values.Endpoint == "" && (values.CredentialFile != "" || values.TLSCertificate != "") {
		return config, errors.New("credentials and certificates require an endpoint")
	}
	config.Discovery.ConfigPath = values.SyncthingConfig
	config.Discovery.Endpoint = values.Endpoint
	config.Discovery.CredentialFile = values.CredentialFile
	config.Discovery.TLSCertificate = values.TLSCertificate
	config.Discovery.ExpectedDeviceID = values.ExpectedDeviceID
	return config, nil
}
