package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func reviewFixture(t *testing.T) (*reviewServer, string) {
	t.Helper()
	root := t.TempDir()
	copy := "report.sync-conflict-20260908-120000-ABCDEFG.txt"
	if err := os.WriteFile(filepath.Join(root, copy), []byte("keep this version"), 0600); err != nil {
		t.Fatal(err)
	}
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-API-Key") != "test-key" || r.URL.Query().Get("folder") != "fixture" {
			t.Error("wrong API request")
			w.WriteHeader(403)
			return
		}
		switch r.URL.Path {
		case "/rest/db/browse":
			json.NewEncoder(w).Encode([]browseNode{{Name: copy, Type: "FILE_INFO_TYPE_FILE"}})
		case "/rest/db/file":
			if r.URL.Query().Get("file") != copy {
				w.WriteHeader(404)
				return
			}
			file := fileInfo{Type: "FILE_INFO_TYPE_FILE", Size: 17, Modified: "2026-09-08T12:00:00Z", BlocksHash: "indexed-hash"}
			json.NewEncoder(w).Encode(map[string]any{"global": file, "local": file})
		case "/rest/db/scan":
			if r.Method != "POST" {
				t.Error("scan was not POST")
			}
		default:
			t.Errorf("unexpected API route %s", r.URL.Path)
			w.WriteHeader(404)
		}
	}))
	t.Cleanup(backend.Close)
	s := &reviewServer{root: root, folder: "fixture", origin: "http://127.0.0.1:18421", apiURL: backend.URL, key: "test-key", token: "test-token", client: backend.Client()}
	s.reveal = func(paths []string, folder bool) error { return nil }
	return s, copy
}

func requestFor(t *testing.T, s *reviewServer, copy string) reviewRequest {
	t.Helper()
	groups, err := s.inventory("")
	if err != nil {
		t.Fatal(err)
	}
	if len(groups) != 1 || groups[0].Current != nil || len(groups[0].Copies) != 1 {
		t.Fatalf("unexpected inventory: %#v", groups)
	}
	g := groups[0]
	return reviewRequest{ID: g.ID, Path: g.Path, Revision: g.Revision, File: copy}
}

func TestReviewRenamePreservesChosenContents(t *testing.T) {
	s, copy := reviewFixture(t)
	body := requestFor(t, s, copy)
	if _, err := s.action("restore-name", body); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(s.root, "report.txt"))
	if err != nil || string(data) != "keep this version" {
		t.Fatalf("restored file: %q, %v", data, err)
	}
	if _, err := os.Stat(filepath.Join(s.root, copy)); !os.IsNotExist(err) {
		t.Fatal("conflict name remains")
	}
}

func TestReviewRejectsStaleAndExistingDestination(t *testing.T) {
	s, copy := reviewFixture(t)
	body := requestFor(t, s, copy)
	stale := body
	stale.Revision = "old"
	if _, err := s.action("restore-name", stale); err == nil {
		t.Fatal("stale review accepted")
	}
	if err := os.WriteFile(filepath.Join(s.root, "report.txt"), []byte("retain destination"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := s.action("restore-name", body); err == nil {
		t.Fatal("existing destination overwritten")
	}
	data, _ := os.ReadFile(filepath.Join(s.root, "report.txt"))
	if string(data) != "retain destination" {
		t.Fatal("destination contents changed")
	}
	if _, err := os.Stat(filepath.Join(s.root, copy)); err != nil {
		t.Fatal("source was lost")
	}
}

func TestReviewDoesNotRevealSymlinksOrOutsidePaths(t *testing.T) {
	s, copy := reviewFixture(t)
	body := requestFor(t, s, copy)
	if err := os.Remove(filepath.Join(s.root, copy)); err != nil {
		t.Fatal(err)
	}
	outside := filepath.Join(t.TempDir(), "outside.txt")
	if err := os.WriteFile(outside, []byte("private"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(s.root, copy)); err != nil {
		t.Fatal(err)
	}
	if _, err := s.action("open", body); err == nil {
		t.Fatal("symlink revealed")
	}
	for _, name := range []string{"../outside.txt", "/etc/passwd", "a/../../file", "a\x00b"} {
		if _, err := s.safeFile(name); err == nil {
			t.Fatalf("outside path accepted: %q", name)
		}
	}
}

func TestReviewRequiresHostOriginAndToken(t *testing.T) {
	s, _ := reviewFixture(t)
	handler := s.handler(nil)
	for _, headers := range []struct{ host, origin, token string }{
		{"evil.test", s.origin, s.token},
		{"127.0.0.1:18421", "http://evil.test", s.token},
		{"127.0.0.1:18421", s.origin, "wrong"},
	} {
		r := httptest.NewRequest("POST", s.origin+"/review/recheck", strings.NewReader("{}"))
		r.Host = headers.host
		r.Header.Set("Origin", headers.origin)
		r.Header.Set("X-Review-Token", headers.token)
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, r)
		if w.Code != 403 {
			t.Fatalf("unauthorized request returned %d", w.Code)
		}
	}
}
