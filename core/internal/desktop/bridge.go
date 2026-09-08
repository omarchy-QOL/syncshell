// Package desktop connects the local browser to bounded user-session actions.
package desktop

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
)

// Bridge lives only as long as the plugin's existing core process.
type Bridge struct {
	launchDir              string
	pid                    int
	client                 *syncthing.Client
	server                 *http.Server
	address, origin, token string
	mu                     sync.Mutex
	launch                 func(context.Context, string) error
}

type request struct {
	Device   string    `json:"device"`
	Folder   string    `json:"folder"`
	Root     string    `json:"root"`
	Path     string    `json:"path"`
	File     string    `json:"file"`
	Size     int64     `json:"size"`
	Modified time.Time `json:"modified"`
}

// New binds an ephemeral loopback port; the token never enters public snapshots.
func New(client *syncthing.Client) (*Bridge, error) {
	endpoint, err := url.Parse(client.Endpoint())
	if err != nil || !client.Target().Local || os.Geteuid() == 0 ||
		(endpoint.Scheme != "http" && endpoint.Scheme != "https") {
		return nil, errors.New("desktop file actions require a local user session")
	}
	if os.Getenv("DBUS_SESSION_BUS_ADDRESS") == "" {
		return nil, errors.New("desktop session is unavailable")
	}
	listener, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		return nil, err
	}
	secret := make([]byte, 32)
	if _, err = rand.Read(secret); err != nil {
		listener.Close()
		return nil, err
	}
	b := &Bridge{
		client:  client,
		address: listener.Addr().String(),
		origin:  endpoint.Scheme + "://" + endpoint.Host,
		token:   hex.EncodeToString(secret),
		launch:  launch,
	}
	b.server = &http.Server{
		Handler:           b,
		ReadHeaderTimeout: 3 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       15 * time.Second,
		MaxHeaderBytes:    8192,
	}
	go b.server.Serve(listener)
	return b, nil
}

// Close stops the endpoint and removes its private launch page.
func (b *Bridge) Close() {
	b.server.Close()
	if b.launchDir != "" {
		os.RemoveAll(b.launchDir)
	}
}

// Open grants only this tab access, without putting a secret into GUI assets.
func (b *Bridge) Open(ctx context.Context) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	endpoint, _ := url.Parse(b.client.Endpoint())
	endpoint.Fragment = "syncshell-desktop=" + b.address + "/" + b.token
	if b.launchDir == "" {
		directory, err := os.MkdirTemp(os.Getenv("XDG_RUNTIME_DIR"), "syncshell-webui-")
		if err != nil {
			return errors.New("could not prepare the private browser launch")
		}
		b.launchDir = directory
	}
	target, _ := json.Marshal(endpoint.String())
	page := filepath.Join(b.launchDir, "open.html")
	// Keep the grant out of process arguments and world-readable theme assets.
	contents := "<!doctype html><meta charset=utf-8><script>location.replace(" +
		string(target) + ")</script>"
	if err := os.WriteFile(page, []byte(contents), 0600); err != nil {
		return errors.New("could not prepare the private browser launch")
	}
	return b.launch(ctx, (&url.URL{Scheme: "file", Path: page}).String())
}

func launch(ctx context.Context, target string) error {
	// Some default applications keep xdg-open alive until their window closes.
	command := exec.Command("xdg-open", target)
	if err := command.Start(); err != nil {
		return errors.New("the default desktop application could not be started")
	}
	done := make(chan error, 1)
	go func() { done <- command.Wait() }()
	select {
	case err := <-done:
		if err != nil {
			return errors.New("the default desktop application refused the request")
		}
	case <-time.After(300 * time.Millisecond):
	case <-ctx.Done():
		return ctx.Err()
	}
	return nil
}

func (b *Bridge) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	if r.Host != b.address || r.Header.Get("Origin") != b.origin {
		http.Error(w, "desktop origin refused", http.StatusForbidden)
		return
	}
	w.Header().Set("Access-Control-Allow-Origin", b.origin)
	w.Header().Set("Vary", "Origin")
	if r.Method == http.MethodOptions {
		w.Header().Set("Access-Control-Allow-Methods", "POST")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, X-Syncshell-Token")
		w.Header().Set("Access-Control-Allow-Private-Network", "true")
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if r.Method != http.MethodPost || subtle.ConstantTimeCompare([]byte(r.Header.Get("X-Syncshell-Token")), []byte(b.token)) != 1 {
		http.Error(w, "desktop authorization refused", http.StatusForbidden)
		return
	}
	body, err := readRequest(w, r)
	if err != nil {
		http.Error(w, "invalid desktop request", http.StatusBadRequest)
		return
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	ctx, cancel := context.WithTimeout(r.Context(), 25*time.Second)
	defer cancel()
	result, err := b.action(ctx, strings.TrimPrefix(r.URL.Path, "/"), body)
	w.Header().Set("Content-Type", "application/json")
	if err != nil {
		w.WriteHeader(http.StatusConflict)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}
	json.NewEncoder(w).Encode(result)
}

func readRequest(w http.ResponseWriter, r *http.Request) (request, error) {
	var body request
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 16<<10))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&body); err != nil {
		return request{}, err
	}
	if err := decoder.Decode(new(any)); err != io.EOF {
		return request{}, errors.New("invalid desktop request")
	}
	return body, nil
}
