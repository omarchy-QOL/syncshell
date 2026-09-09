//go:build linux

package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func releaseFixture(t *testing.T, change func(map[string]string), extra *tar.Header) []byte {
	t.Helper()
	files := map[string]string{
		"gui/syncshell-modern/index.html":      "new UI",
		"integration/omarchy-theme.css.in":     "body {}",
		"integration/omarchy-theme-refresh.js": "refresh()",
		"install.sh":                           "installer",
		"manifest.json":                        `{"name":"syncshell-webui","version":"0.1.2","source":"` + strings.Repeat("a", 40) + `","integrationFormat":1}`,
	}
	for name, data := range files {
		if name != "SHA256SUMS" {
			files["SHA256SUMS"] += digest([]byte(data)) + "  " + name + "\n"
		}
	}
	if change != nil {
		change(files)
	}
	var data bytes.Buffer
	compressed := gzip.NewWriter(&data)
	archive := tar.NewWriter(compressed)
	for name, content := range files {
		if err := archive.WriteHeader(&tar.Header{Name: "syncshell-webui-v0.1.2/" + name, Mode: 0644, Size: int64(len(content))}); err != nil {
			t.Fatal(err)
		}
		if _, err := archive.Write([]byte(content)); err != nil {
			t.Fatal(err)
		}
	}
	if extra != nil {
		if err := archive.WriteHeader(extra); err != nil {
			t.Fatal(err)
		}
	}
	if err := archive.Close(); err != nil {
		t.Fatal(err)
	}
	if err := compressed.Close(); err != nil {
		t.Fatal(err)
	}
	return data.Bytes()
}

func TestImportReplacesOnlyBundleAndRecordsPin(t *testing.T) {
	root := t.TempDir()
	data := releaseFixture(t, nil, nil)
	if err := os.WriteFile(filepath.Join(root, "owner"), []byte("retain"), 0600); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 2; i++ {
		if err := importRelease(root, "0.1.2", digest(data), data); err != nil {
			t.Fatal(err)
		}
		if _, err := os.Stat(filepath.Join(root, "webui", "obsolete")); !os.IsNotExist(err) {
			t.Fatal("obsolete asset retained")
		}
		if err := os.WriteFile(filepath.Join(root, "webui", "obsolete"), nil, 0600); err != nil {
			t.Fatal(err)
		}
	}
	content, _ := os.ReadFile(filepath.Join(root, "webui", "import.json"))
	var pin map[string]string
	if err := json.Unmarshal(content, &pin); err != nil || pin["sha256"] != digest(data) || pin["version"] != "0.1.2" {
		t.Fatalf("incorrect release pin: %s", content)
	}
	content, _ = os.ReadFile(filepath.Join(root, "owner"))
	if string(content) != "retain" {
		t.Fatal("unrelated owner file changed")
	}
}

func TestRejectedReleaseLeavesBundleUntouched(t *testing.T) {
	cases := []struct {
		name   string
		change func(map[string]string)
		extra  *tar.Header
	}{
		{"bad asset", func(f map[string]string) { f["gui/syncshell-modern/index.html"] = "corrupt" }, nil},
		{"missing asset", func(f map[string]string) { delete(f, "install.sh") }, nil},
		{"unlisted asset", func(f map[string]string) { f["extra"] = "unlisted" }, nil},
		{"wrong manifest", func(f map[string]string) { f["manifest.json"] = `{}` }, nil},
		{"traversal", nil, &tar.Header{Name: "syncshell-webui-v0.1.2/../../owner", Typeflag: tar.TypeReg}},
		{"symlink", nil, &tar.Header{Name: "syncshell-webui-v0.1.2/link", Typeflag: tar.TypeSymlink, Linkname: "/tmp"}},
		{"duplicate", nil, &tar.Header{Name: "syncshell-webui-v0.1.2/install.sh", Typeflag: tar.TypeReg}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			root := t.TempDir()
			if err := os.Mkdir(filepath.Join(root, "webui"), 0700); err != nil {
				t.Fatal(err)
			}
			old := filepath.Join(root, "webui", "working")
			if err := os.WriteFile(old, []byte("retain"), 0600); err != nil {
				t.Fatal(err)
			}
			data := releaseFixture(t, tc.change, tc.extra)
			if err := importRelease(root, "0.1.2", digest(data), data); err == nil {
				t.Fatal("invalid release accepted")
			}
			if content, _ := os.ReadFile(old); string(content) != "retain" {
				t.Fatal("failed import changed the working bundle")
			}
		})
	}
}

func TestChecksumAndLinkedTargetAreRejected(t *testing.T) {
	root, owner := t.TempDir(), t.TempDir()
	data := releaseFixture(t, nil, nil)
	if err := importRelease(root, "0.1.2", strings.Repeat("0", 64), data); err == nil {
		t.Fatal("incorrect archive checksum accepted")
	}
	if err := os.Symlink(owner, filepath.Join(root, "webui")); err != nil {
		t.Fatal(err)
	}
	if err := importRelease(root, "0.1.2", digest(data), data); err == nil {
		t.Fatal("linked target accepted")
	}
	if entries, _ := os.ReadDir(owner); len(entries) != 0 {
		t.Fatal(fmt.Sprint("linked owner directory changed: ", entries))
	}
}
