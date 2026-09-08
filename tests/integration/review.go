package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"golang.org/x/sys/unix"
)

type fileRecord struct {
	Path      string `json:"path"`
	Name      string `json:"name"`
	Bytes     int64  `json:"bytes"`
	Modified  string `json:"modified"`
	Digest    any    `json:"digest"`
	Available bool   `json:"available"`
}

type conflictGroup struct {
	ID       string        `json:"id"`
	Path     string        `json:"path"`
	Name     string        `json:"name"`
	Current  *fileRecord   `json:"current"`
	Copies   []*fileRecord `json:"copies"`
	Revision string        `json:"revision"`
}

type fileInfo struct {
	Type                                  string `json:"type"`
	Size                                  int64  `json:"size"`
	Modified                              string `json:"modified"`
	BlocksHash                            any    `json:"blocksHash"`
	Deleted, Ignored, Invalid, MustRescan bool
}

func (f fileInfo) usable() bool {
	return f.Type == "FILE_INFO_TYPE_FILE" && !f.Deleted && !f.Ignored && !f.Invalid && !f.MustRescan
}

type reviewServer struct {
	root, folder, origin, apiURL, key, token string
	client                                   *http.Client
	mu                                       sync.Mutex
	reveal                                   func([]string, bool) error
}

type reviewRequest struct {
	ID       string `json:"id"`
	Path     string `json:"path"`
	Revision string `json:"revision"`
	File     string `json:"file"`
	All      bool   `json:"all"`
}

var conflictMarker = regexp.MustCompile(`^(.*)\.sync-conflict-\d{8}-\d{6}-[A-Z2-7]{7}(\..*)?$`)

func canonicalName(name string) string {
	m := conflictMarker.FindStringSubmatch(path.Base(name))
	if m == nil || conflictMarker.MatchString(m[1]+m[2]) {
		return ""
	}
	return path.Join(path.Dir(name), m[1]+m[2])
}

func relative(name string) error {
	if name == "" || strings.ContainsRune(name, 0) || path.IsAbs(name) || path.Clean(name) != name {
		return errors.New("file is outside the review directory")
	}
	for _, part := range strings.Split(name, "/") {
		if part == ".." {
			return errors.New("file is outside the review directory")
		}
	}
	return nil
}

func digest(value []byte) string {
	sum := sha256.Sum256(value)
	return hex.EncodeToString(sum[:])
}

func (s *reviewServer) api(endpoint, method string, params url.Values, result any) error {
	if params == nil {
		params = url.Values{}
	}
	params.Set("folder", s.folder)
	req, err := http.NewRequest(method, s.apiURL+"/rest/"+endpoint+"?"+params.Encode(), nil)
	if err != nil {
		return err
	}
	req.Header.Set("X-API-Key", s.key)
	response, err := s.client.Do(req)
	if err != nil {
		return errors.New("Syncthing index unavailable")
	}
	defer response.Body.Close()
	if response.StatusCode == 404 && endpoint == "db/file" {
		return nil
	}
	if response.StatusCode != 200 {
		return fmt.Errorf("Syncthing %s failed (%d)", endpoint, response.StatusCode)
	}
	if result != nil {
		return json.NewDecoder(response.Body).Decode(result)
	}
	_, err = io.Copy(io.Discard, response.Body)
	return err
}

func (s *reviewServer) record(name string) (*fileRecord, error) {
	var info struct{ Global, Local fileInfo }
	if err := s.api("db/file", "GET", url.Values{"file": {name}}, &info); err != nil {
		return nil, err
	}
	if !info.Global.usable() {
		return nil, nil
	}
	f, available := info.Global, info.Local.usable()
	if available {
		f = info.Local
	}
	var hash any
	if available {
		hash = f.BlocksHash
	}
	return &fileRecord{name, path.Base(name), f.Size, f.Modified, hash, available}, nil
}

type browseNode struct {
	Name, Type string
	Children   []browseNode
}

func (s *reviewServer) inventory(canonical string) ([]*conflictGroup, error) {
	prefix := ""
	if canonical != "" {
		if err := relative(canonical); err != nil {
			return nil, err
		}
		prefix = path.Dir(canonical)
		if prefix == "." {
			prefix = ""
		}
	}
	var nodes []browseNode
	if err := s.api("db/browse", "GET", url.Values{"prefix": {prefix}}, &nodes); err != nil {
		return nil, err
	}
	groups := map[string]*conflictGroup{}
	var visit func([]browseNode, string) error
	visit = func(nodes []browseNode, parent string) error {
		for _, node := range nodes {
			name := path.Join(parent, node.Name)
			if err := relative(name); err != nil {
				return err
			}
			if node.Type == "FILE_INFO_TYPE_DIRECTORY" {
				if err := visit(node.Children, name); err != nil {
					return err
				}
				continue
			}
			original := canonicalName(name)
			if node.Type != "FILE_INFO_TYPE_FILE" || original == "" || canonical != "" && canonical != original {
				continue
			}
			copy, err := s.record(name)
			if err != nil {
				return err
			}
			if copy == nil {
				continue
			}
			if groups[original] == nil {
				groups[original] = &conflictGroup{ID: digest([]byte(original))[:20], Path: original, Name: path.Base(original)}
			}
			groups[original].Copies = append(groups[original].Copies, copy)
		}
		return nil
	}
	if err := visit(nodes, prefix); err != nil {
		return nil, err
	}
	result := make([]*conflictGroup, 0, len(groups))
	for name, group := range groups {
		var err error
		group.Current, err = s.record(name)
		if err != nil {
			return nil, err
		}
		sort.Slice(group.Copies, func(i, j int) bool { return group.Copies[i].Name > group.Copies[j].Name })
		data, _ := json.Marshal([]any{group.Current, group.Copies})
		group.Revision = digest(data)
		result = append(result, group)
	}
	sort.Slice(result, func(i, j int) bool { return result[i].Path < result[j].Path })
	return result, nil
}

func (s *reviewServer) scan(name string) error {
	params := url.Values{}
	if name != "" {
		parent := path.Dir(name)
		if parent == "." {
			parent = ""
		}
		params.Set("sub", parent)
	}
	return s.api("db/scan", "POST", params, nil)
}

func (s *reviewServer) find(body reviewRequest) (*conflictGroup, error) {
	if err := relative(body.Path); err != nil {
		return nil, err
	}
	if digest([]byte(body.Path))[:20] != body.ID {
		return nil, errors.New("unknown file")
	}
	groups, err := s.inventory(body.Path)
	if err != nil {
		return nil, err
	}
	if len(groups) != 1 {
		return nil, errors.New("these conflict files are no longer present; recheck the list")
	}
	if groups[0].Revision != body.Revision {
		return nil, errors.New("these files changed after the list was loaded; recheck before resolving")
	}
	return groups[0], nil
}

func (s *reviewServer) safeFile(name string) (string, error) {
	if err := relative(name); err != nil {
		return "", err
	}
	p := filepath.Join(s.root, filepath.FromSlash(name))
	resolved, err := filepath.EvalSymlinks(p)
	if err != nil {
		return "", err
	}
	if resolved != p {
		return "", errors.New("symlinks are not review files")
	}
	info, err := os.Stat(p)
	if err != nil {
		return "", err
	}
	if !info.Mode().IsRegular() {
		return "", errors.New("file is no longer available; recheck the list")
	}
	return p, nil
}

func (s *reviewServer) action(route string, body reviewRequest) (any, error) {
	if route == "recheck" {
		if body.ID != "" && (relative(body.Path) != nil || digest([]byte(body.Path))[:20] != body.ID) {
			return nil, errors.New("unknown file")
		}
		if err := s.scan(body.Path); err != nil {
			return nil, err
		}
		groups, err := s.inventory(body.Path)
		return map[string]any{"groups": groups, "root": s.root}, err
	}
	if route == "restore-name" {
		if err := relative(body.Path); err != nil {
			return nil, err
		}
		if err := s.scan(body.Path); err != nil {
			return nil, err
		}
	}
	group, err := s.find(body)
	if err != nil {
		return nil, err
	}
	if route == "restore-name" {
		if group.Current != nil {
			return nil, errors.New("a current file exists; recheck before resolving")
		}
		var selected *fileRecord
		for _, f := range group.Copies {
			if f.Path == body.File && f.Available {
				selected = f
			}
		}
		if selected == nil {
			return nil, errors.New("choose an available conflict file")
		}
		source, err := s.safeFile(selected.Path)
		if err != nil {
			return nil, err
		}
		target := filepath.Join(s.root, filepath.FromSlash(group.Path))
		if filepath.Dir(source) != filepath.Dir(target) {
			return nil, errors.New("rename must stay in the same directory")
		}
		fd, err := unix.Open(filepath.Dir(source), unix.O_RDONLY|unix.O_DIRECTORY|unix.O_NOFOLLOW, 0)
		if err != nil {
			return nil, err
		}
		defer unix.Close(fd)
		if err := unix.Renameat2(fd, filepath.Base(source), fd, filepath.Base(target), unix.RENAME_NOREPLACE); err != nil {
			return nil, err
		}
		result := map[string]any{"renamed": group.Path}
		if err := s.scan(group.Path); err != nil {
			result["warning"] = "Renamed successfully, but the Syncthing recheck failed. Recheck again."
		} else if groups, err := s.inventory(group.Path); err != nil {
			result["warning"] = "Renamed successfully, but the Syncthing recheck failed. Recheck again."
		} else {
			result["groups"] = groups
		}
		return result, nil
	}
	if route != "open" {
		return nil, errors.New("unknown review action")
	}
	files := append([]*fileRecord{}, group.Copies...)
	if group.Current != nil {
		files = append(files, group.Current)
	}
	var paths []string
	seen := map[string]bool{}
	for _, file := range files {
		if !body.All && file.Path != body.File {
			continue
		}
		if !file.Available {
			return nil, errors.New("file is not available locally")
		}
		p, err := s.safeFile(file.Path)
		if err != nil {
			return nil, err
		}
		if body.All {
			p = filepath.Dir(p)
		}
		if !seen[p] {
			paths = append(paths, p)
			seen[p] = true
		}
	}
	if len(paths) == 0 {
		return nil, errors.New("choose an available file")
	}
	if err := s.reveal(paths, body.All); err != nil {
		return nil, err
	}
	return map[string]int{"opened": len(paths)}, nil
}

func reply(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(value)
}

func (s *reviewServer) handler(script []byte) http.Handler {
	upstream, _ := url.Parse(s.apiURL)
	proxy := httputil.NewSingleHostReverseProxy(upstream)
	director := proxy.Director
	proxy.Director = func(r *http.Request) {
		director(r)
		r.Host = upstream.Host
		r.Header.Set("Accept-Encoding", "identity")
		for _, key := range []string{"Origin", "Referer"} {
			if strings.HasPrefix(r.Header.Get(key), s.origin) {
				r.Header.Set(key, s.apiURL+strings.TrimPrefix(r.Header.Get(key), s.origin))
			}
		}
	}
	proxy.ModifyResponse = func(r *http.Response) error {
		if r.StatusCode != 200 || r.Request.URL.Path != "/" && r.Request.URL.Path != "/index.html" {
			return nil
		}
		data, err := io.ReadAll(r.Body)
		r.Body.Close()
		if err != nil {
			return err
		}
		data = bytes.Replace(data, []byte("</head>"), []byte(`<meta name="review-token" content="`+s.token+`"><script src="/review/host-actions.js"></script></head>`), 1)
		r.Body = io.NopCloser(bytes.NewReader(data))
		r.ContentLength = int64(len(data))
		r.Header.Set("Content-Length", fmt.Sprint(len(data)))
		return nil
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if "http://"+r.Host != s.origin {
			reply(w, 403, map[string]string{"error": "wrong host"})
			return
		}
		if r.Method != "GET" && r.Method != "HEAD" && r.Header.Get("Origin") != s.origin {
			reply(w, 403, map[string]string{"error": "wrong origin"})
			return
		}
		if !strings.HasPrefix(r.URL.Path, "/review/") {
			proxy.ServeHTTP(w, r)
			return
		}
		if r.Method == "GET" && r.URL.Path == "/review/host-actions.js" {
			w.Header().Set("Content-Type", "text/javascript")
			w.Write(script)
			return
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		if r.Method == "GET" && r.URL.Path == "/review/list" {
			groups, err := s.inventory("")
			if err != nil {
				reply(w, 502, map[string]string{"error": err.Error()})
				return
			}
			reply(w, 200, map[string]any{"groups": groups, "root": s.root, "host": hostName()})
			return
		}
		if r.Method != "POST" || subtle.ConstantTimeCompare([]byte(r.Header.Get("X-Review-Token")), []byte(s.token)) != 1 {
			reply(w, 403, map[string]string{"error": "review authorization required"})
			return
		}
		var body reviewRequest
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 8192)).Decode(&body); err != nil {
			reply(w, 400, map[string]string{"error": "invalid request"})
			return
		}
		result, err := s.action(strings.TrimPrefix(r.URL.Path, "/review/"), body)
		if err != nil {
			reply(w, 409, map[string]string{"error": err.Error()})
			return
		}
		reply(w, 200, result)
	})
}

func newReview(runtime, folder, listen string) (*reviewServer, error) {
	if _, err := os.Stat(filepath.Join(runtime, ".syncshell-port-fixture")); err != nil {
		return nil, errors.New("unmarked test runtime")
	}
	var config struct {
		GUI struct {
			Address string `xml:"address"`
			APIKey  string `xml:"apikey"`
		} `xml:"gui"`
		Folders []struct {
			ID   string `xml:"id,attr"`
			Path string `xml:"path,attr"`
		} `xml:"folder"`
	}
	data, err := os.ReadFile(filepath.Join(runtime, "home/config.xml"))
	if err != nil {
		return nil, err
	}
	if err := xml.Unmarshal(data, &config); err != nil {
		return nil, err
	}
	root, err := filepath.Abs(filepath.Join(runtime, "files"))
	if err != nil {
		return nil, err
	}
	match := false
	for _, f := range config.Folders {
		if f.ID == folder && filepath.Clean(f.Path) == root {
			match = true
		}
	}
	if !match || !strings.HasPrefix(config.GUI.Address, "127.0.0.1:") || !strings.HasPrefix(listen, "127.0.0.1:") {
		return nil, errors.New("review requires the marked folder and loopback addresses")
	}
	secret := make([]byte, 32)
	if _, err := rand.Read(secret); err != nil {
		return nil, err
	}
	s := &reviewServer{root: root, folder: folder, origin: "http://" + listen, apiURL: "http://" + config.GUI.Address, key: config.GUI.APIKey, token: hex.EncodeToString(secret), client: &http.Client{Timeout: 90 * time.Second}}
	s.reveal = func(paths []string, folders bool) error {
		uris := make([]string, len(paths))
		for i, p := range paths {
			uris[i] = (&url.URL{Scheme: "file", Path: p}).String()
		}
		payload, _ := json.Marshal(uris)
		method := "ShowItems"
		if folders {
			method = "ShowFolders"
		}
		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()
		if err := exec.CommandContext(ctx, "gdbus", "call", "--session", "--dest", "org.freedesktop.FileManager1", "--object-path", "/org/freedesktop/FileManager1", "--method", "org.freedesktop.FileManager1."+method, string(payload), "").Run(); err != nil {
			return err
		}
		log, err := os.OpenFile(filepath.Join(runtime, "evidence/open-actions.jsonl"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0600)
		if err != nil {
			return err
		}
		defer log.Close()
		return json.NewEncoder(log).Encode(map[string]any{"files": paths, "time": time.Now().Unix()})
	}
	return s, nil
}

func hostName() string { name, _ := os.Hostname(); return name }
