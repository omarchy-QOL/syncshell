package nativebridge

import (
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"sort"
)

type directoryEntry struct {
	Name string `json:"name"`
	Path string `json:"path"`
}

// Browse is a short-lived directory picker operation, without Syncthing access.
func Browse(args []string, output io.Writer) error {
	if len(args) < 1 || len(args) > 2 || !filepath.IsAbs(args[0]) {
		return errors.New("directory browsing requires an absolute path")
	}
	path := filepath.Clean(args[0])
	after := ""
	if len(args) == 2 {
		after = args[1]
	}
	directory, err := os.Open(path)
	if err != nil {
		return errors.New("directory is unavailable or permission was denied")
	}
	defer directory.Close()
	entries := make([]directoryEntry, 0, 257)
	for {
		batch, err := directory.ReadDir(256)
		if err != nil && err != io.EOF {
			return errors.New("cannot list directory")
		}
		for _, entry := range batch {
			if entry.Name() <= after {
				continue
			}
			full := filepath.Join(path, entry.Name())
			info, err := os.Stat(full)
			if err == nil && info.IsDir() {
				entries = append(entries, directoryEntry{entry.Name(), full})
			}
		}
		sort.Slice(entries, func(i, j int) bool { return entries[i].Name < entries[j].Name })
		if len(entries) > 257 {
			entries = entries[:257]
		}
		if err == io.EOF {
			break
		}
	}
	next := ""
	if len(entries) > 256 {
		entries = entries[:256]
		next = entries[255].Name
	}
	return json.NewEncoder(output).Encode(struct {
		Path    string           `json:"path"`
		Parent  string           `json:"parent"`
		Entries []directoryEntry `json:"entries"`
		Next    string           `json:"next"`
	}{path, filepath.Dir(path), entries, next})
}
