package session

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
)

func TestDirectoryCreationRequiresConfirmation(t *testing.T) {
	path := filepath.Join(t.TempDir(), "new", "folder")
	api := &actionAPI{
		folders: map[string]syncthing.Folder{},
		devices: []syncthing.Device{{DeviceID: "LOCAL"}},
	}
	s := newActionSession(t, api)
	if _, err := s.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	args := ActionArguments{FolderID: "new-folder", Path: path}
	result := s.Act(context.Background(), "folder.add-existing", args)
	if result.Error == nil || result.Error.Code != "path_missing" {
		t.Fatalf("expected creation confirmation: %#v", result)
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) || api.hasFolder(args.FolderID) {
		t.Fatal("unconfirmed submission created a directory or configuration")
	}
	args.CreateDirectory = true
	args.DeviceIDs = []string{"UNKNOWN"}
	result = s.Act(context.Background(), "folder.add-existing", args)
	if result.Error == nil || result.Error.Code != "device_invalid" {
		t.Fatalf("invalid sharing accepted: %#v", result)
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatal("directory created before sharing validation")
	}
	args.DeviceIDs = nil
	result = s.Act(context.Background(), "folder.add-existing", args)
	if !result.OK || !api.hasFolder(args.FolderID) {
		t.Fatalf("confirmed creation failed: %#v", result)
	}
	if info, err := os.Stat(path); err != nil || !info.IsDir() {
		t.Fatalf("directory not created: %v", err)
	}
	if api.folder(args.FolderID).Path != path {
		t.Fatalf("wrong configured path: %q", api.folder(args.FolderID).Path)
	}
}

func TestDirectoryCreationRejectsOverlap(t *testing.T) {
	parent := t.TempDir()
	path := filepath.Join(parent, "nested")
	api := &actionAPI{
		folders: map[string]syncthing.Folder{"existing": {ID: "existing", Path: parent}},
		devices: []syncthing.Device{{DeviceID: "LOCAL"}},
	}
	s := newActionSession(t, api)
	if _, err := s.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	result := s.Act(context.Background(), "folder.add-existing", ActionArguments{
		FolderID: "new", Path: path, CreateDirectory: true,
	})
	if result.Error == nil || result.Error.Code != "path_overlap" {
		t.Fatalf("overlap accepted: %#v", result)
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatal("overlapping directory created")
	}
}

func TestCanonicalDirectoryClassifiesMissingPaths(t *testing.T) {
	parent := t.TempDir()
	link := filepath.Join(parent, "link")
	broken := filepath.Join(parent, "broken")
	file := filepath.Join(parent, "file")
	if err := os.Symlink(parent, link); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(parent, "absent"), broken); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(file, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	for _, tc := range []struct {
		name, path, wantPath, code string
	}{
		{"existing", parent + "/", parent, ""},
		{"missing", filepath.Join(parent, "new", "child"), filepath.Join(parent, "new", "child"), "path_missing"},
		{"symlink parent", filepath.Join(link, "new"), filepath.Join(parent, "new"), "path_missing"},
		{"broken symlink", broken, "", "path_unavailable"},
		{"broken ancestor", filepath.Join(broken, "child"), "", "path_unavailable"},
		{"file", file, "", "path_invalid"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			resolved, result := canonicalDirectory(tc.path)
			if resolved != tc.wantPath {
				t.Fatalf("resolved %q, want %q", resolved, tc.wantPath)
			}
			if tc.code == "" {
				if result != nil {
					t.Fatalf("unexpected error: %#v", result)
				}
			} else if result == nil || result.Error.Code != tc.code {
				t.Fatalf("expected %s, got %#v", tc.code, result)
			}
		})
	}
}

func TestCanonicalDirectoryPermissionErrorIsNotMissing(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root bypasses directory permissions")
	}
	parent := t.TempDir()
	if err := os.Chmod(parent, 0); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(parent, 0o700) })
	_, result := canonicalDirectory(filepath.Join(parent, "new"))
	if result == nil || result.Error.Code != "path_unavailable" {
		t.Fatalf("permission error offered creation: %#v", result)
	}
}

func TestDirectoryCreationFlagIsOnlyForFolderAddition(t *testing.T) {
	result := validateActionArguments("folder.pause", ActionArguments{
		FolderID: "folder", CreateDirectory: true,
	})
	if result == nil || result.Error.Code != "invalid_action" {
		t.Fatalf("unexpected creation flag accepted: %#v", result)
	}
}
