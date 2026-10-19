package nativebridge

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func TestBrowsePagesKeepDirectoryIdentity(t *testing.T) {
	root := t.TempDir()
	for i := 0; i < 270; i++ {
		if err := os.Mkdir(filepath.Join(root, fmt.Sprintf("folder %03d", i)), 0700); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(root, "not a directory"), nil, 0600); err != nil {
		t.Fatal(err)
	}
	var output bytes.Buffer
	if err := Browse([]string{root, ""}, &output); err != nil {
		t.Fatal(err)
	}
	var page struct {
		Path, Next string
		Entries    []struct{ Name, Path string }
	}
	if err := json.Unmarshal(output.Bytes(), &page); err != nil {
		t.Fatal(err)
	}
	if page.Path != root || len(page.Entries) != 256 || page.Next == "" {
		t.Fatalf("invalid first page: %#v", page)
	}
	cursor := page.Next
	output.Reset()
	if err := Browse([]string{root, cursor}, &output); err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(output.Bytes(), &page); err != nil {
		t.Fatal(err)
	}
	if len(page.Entries) != 14 || page.Entries[0].Name <= cursor {
		t.Fatalf("pagination skipped or repeated entries: %#v", page)
	}
	if err := Browse([]string{"relative", ""}, &output); err == nil {
		t.Fatal("accepted relative path")
	}
}
