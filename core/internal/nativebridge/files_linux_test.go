package nativebridge

import (
	"os"
	"path/filepath"
	"testing"
)

func TestRequestFilesEnforcePrivateOwnership(t *testing.T) {
	dir := t.TempDir()
	for _, kind := range []string{"symlink", "hardlink", "public", "directory", "valid"} {
		t.Run(kind, func(t *testing.T) {
			path := filepath.Join(dir, "request-test.json")
			defer os.Remove(path)
			target := filepath.Join(t.TempDir(), "target")
			if err := os.WriteFile(target, []byte(`{"v":2}`), 0o600); err != nil {
				t.Fatal(err)
			}
			var err error
			switch kind {
			case "symlink":
				err = os.Symlink(target, path)
			case "hardlink":
				err = os.Link(target, path)
			case "directory":
				err = os.Mkdir(path, 0o700)
			case "public":
				err = os.WriteFile(path, []byte(`{}`), 0o644)
			case "valid":
				err = os.WriteFile(path, []byte(`{}`), 0o600)
			}
			if err != nil {
				t.Fatal(err)
			}
			_, err = consumeRequest(dir, "request-test.json")
			if (err == nil) != (kind == "valid") {
				t.Fatalf("%s: %v", kind, err)
			}
			if _, err := os.Stat(target); err != nil {
				t.Fatal("modified external target")
			}
		})
	}
	if _, err := consumeRequest(dir, "../request-escape.json"); err == nil {
		t.Fatal("accepted path traversal")
	}
}

func TestCleanupDoesNotFollowSymlinks(t *testing.T) {
	base := t.TempDir()
	out := t.TempDir()
	if err := os.Symlink(out, filepath.Join(base, "generation-123")); err != nil {
		t.Fatal(err)
	}
	if err := cleanGenerations(base); err == nil {
		t.Fatal("cleanup accepted a symlink")
	}
	if _, err := os.Stat(out); err != nil {
		t.Fatal("cleanup removed external directory")
	}
}
