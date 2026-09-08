package desktop

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
)

func TestGuardedRename(t *testing.T) {
	for _, scenario := range []string{"rename", "existing", "stale", "symlink", "escape", "unrelated", "readonly", "open"} {
		t.Run(scenario, func(t *testing.T) {
			root := t.TempDir()
			source := "notes.sync-conflict-20260908-123456-ABCDEFG.txt"
			path := filepath.Join(root, source)
			if err := os.WriteFile(path, []byte("keep this version"), 0600); err != nil {
				t.Fatal(err)
			}
			info, _ := os.Stat(path)
			body := request{Root: root, Path: "notes.txt", File: source, Size: info.Size(), Modified: info.ModTime()}
			opened := ""
			b := &Bridge{launch: func(_ context.Context, path string) error { opened = path; return nil }}
			action := "rename"
			switch scenario {
			case "existing":
				os.WriteFile(filepath.Join(root, "notes.txt"), []byte("original"), 0600)
			case "stale":
				body.Modified = time.Unix(1, 0)
			case "symlink":
				os.Remove(path)
				os.Symlink("/etc/passwd", path)
			case "escape":
				body.File = "../" + source
			case "unrelated":
				body.Path = "other.txt"
			case "readonly":
				if os.Geteuid() == 0 {
					t.Skip("root bypasses directory permissions")
				}
				os.Chmod(root, 0500)
				defer os.Chmod(root, 0700)
			case "open":
				action = "open"
			}
			_, err := b.fileAction(context.Background(), action, body, syncthing.Folder{Path: root}, root)
			if scenario == "rename" {
				if err != nil {
					t.Fatal(err)
				}
				data, err := os.ReadFile(filepath.Join(root, "notes.txt"))
				if err != nil || string(data) != "keep this version" {
					t.Fatal("rename did not retain contents")
				}
				if _, err = os.Stat(path); !os.IsNotExist(err) {
					t.Fatal("conflict name remains")
				}
			} else if scenario == "open" {
				if err != nil || opened != root {
					t.Fatalf("open containing directory: %q %v", opened, err)
				}
			} else if err == nil {
				t.Fatal("unsafe rename accepted")
			}
			if scenario == "existing" {
				data, _ := os.ReadFile(filepath.Join(root, "notes.txt"))
				if string(data) != "original" {
					t.Fatal("original replaced")
				}
			}
		})
	}
}

func TestDirectoryRejectsIntermediateSymlink(t *testing.T) {
	root := t.TempDir()
	outside := t.TempDir()
	os.Symlink(outside, filepath.Join(root, "redirect"))
	if _, err := directory(root, "redirect"); err == nil {
		t.Fatal("followed symlink outside folder")
	}
}

func TestConflictNames(t *testing.T) {
	for input, want := range map[string]string{
		"a/report.sync-conflict-20260908-123456-ABCDEFG.tar.gz": "a/report.tar.gz",
		"notes.sync-conflict-20260908-123456-ABCDEFG":           "notes",
		"notes.txt": "",
		"a.sync-conflict-20260908-123456-ABCDEFG.sync-conflict-20260908-123456-ABCDEFG.txt": "",
	} {
		if got := original(input); got != want {
			t.Errorf("%s: %q, want %q", input, got, want)
		}
	}
}
