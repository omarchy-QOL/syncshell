package session

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
	"github.com/omarchy-QOL/syncshell/core/internal/webprofile"
)

func profileSession(t *testing.T) (*Session, *actionAPI) {
	t.Helper()
	api := &actionAPI{folders: map[string]syncthing.Folder{},
		devices: []syncthing.Device{{DeviceID: "LOCAL"}},
		pending: syncthing.PendingFolders{}, theme: "default", guiAssets: t.TempDir()}
	s := newActionSession(t, api)
	bundle, err := filepath.Abs("../../../webui")
	if err != nil {
		t.Fatal(err)
	}
	s.webProfile = webprofile.Policy{Authorized: true, Owner: "test", Bundle: bundle}
	if _, err := s.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	return s, api
}

func TestProfileActionVerifiesThemeAndOwnedFileOutcomes(t *testing.T) {
	s, api := profileSession(t)
	api.setDropThemeResponse(true)
	result := s.Act(context.Background(), "webui.apply-profile", ActionArguments{Profile: "modern"})
	if !result.OK || api.currentTheme() != "syncshell-test-modern" ||
		s.Current().State.WebUI.Theme != "syncshell-test-modern" {
		t.Fatalf("profile theme was not verified: %#v", result)
	}
	profile := filepath.Join(api.guiAssets, "syncshell-test-modern")
	if _, err := os.Stat(filepath.Join(profile, "index.html")); err != nil {
		t.Fatal(err)
	}
	other := filepath.Join(api.guiAssets, "another-adapter")
	if err := os.Mkdir(other, 0700); err != nil {
		t.Fatal(err)
	}
	result = s.Act(context.Background(), "webui.remove-profile", ActionArguments{})
	if !result.OK || api.currentTheme() != "default" || s.Current().State.WebUI.Theme != "default" {
		t.Fatalf("profile cleanup did not verify default theme: %#v", result)
	}
	if _, err := os.Stat(profile); !os.IsNotExist(err) {
		t.Fatalf("owned profile remains: %v", err)
	}
	if _, err := os.Stat(other); err != nil {
		t.Fatal("another adapter's directory was changed", err)
	}
}

func TestProfileActionRejectsChangedAssetDirectory(t *testing.T) {
	s, api := profileSession(t)
	changed := t.TempDir()
	api.mu.Lock()
	api.guiAssets = changed
	api.mu.Unlock()
	result := s.Act(context.Background(), "webui.apply-profile", ActionArguments{Profile: "modern"})
	if result.OK || result.Error == nil || result.Error.Code != "profile_target_changed" {
		t.Fatalf("changed profile destination was accepted: %#v", result)
	}
	entries, err := os.ReadDir(changed)
	if err != nil || len(entries) != 0 {
		t.Fatalf("changed destination was written: %v %v", entries, err)
	}
}

func TestProfileAuthorityRequiresLocalSelectedConfiguration(t *testing.T) {
	s := &Session{}
	s.current.State.Connection.Online = true
	for _, setup := range []func(){
		func() {},
		func() { s.webProfile = webprofile.Policy{Authorized: true, Owner: "test", Bundle: "/bundle"} },
		func() { s.target.Local = true },
	} {
		setup()
		_, failure := s.profileAssets(context.Background())
		if failure == nil || failure.Error.Code != "profile_forbidden" {
			t.Fatalf("unverified local profile authority: %#v", failure)
		}
	}
}

func TestProfileArgumentIsolation(t *testing.T) {
	if result := validateActionArguments("webui.apply-profile", ActionArguments{
		Profile: "modern", Path: t.TempDir(),
	}); result == nil {
		t.Fatal("caller-selected output path was accepted")
	}
	if result := validateActionArguments("webui.remove-profile", ActionArguments{
		Profile: "modern",
	}); result == nil {
		t.Fatal("cleanup accepted caller-selected profile names")
	}
	if result := validateActionArguments("webui.apply-profile", ActionArguments{
		Profile: "themed", Palette: map[string]string{"mode": "dark"},
	}); result == nil {
		t.Fatal("incomplete semantic palette was accepted")
	}
}

func TestCleanupNeverDeletesUnmarkedDirectory(t *testing.T) {
	assets := t.TempDir()
	p := webprofile.Policy{Authorized: true, Owner: "test", Bundle: "/bundle"}
	name, _ := p.Name("modern")
	path := filepath.Join(assets, name)
	if err := os.Mkdir(path, 0700); err != nil {
		t.Fatal(err)
	}
	if err := p.Remove(assets); err == nil {
		t.Fatal("unmarked profile was accepted")
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatal("unmarked directory was removed")
	}
}

func TestPaletteRefreshNeverReclaimsAnotherProfile(t *testing.T) {
	s, api := profileSession(t)
	result := s.Act(context.Background(), "webui.apply-profile", ActionArguments{Profile: "modern"})
	if !result.OK {
		t.Fatal(result.Error)
	}
	api.mu.Lock()
	api.theme = "another-adapter"
	api.mu.Unlock()
	result = s.Act(context.Background(), "webui.refresh-profile", ActionArguments{Profile: "modern"})
	if result.OK || result.Error.Code != "profile_not_selected" {
		t.Fatalf("stale palette refresh accepted: %#v", result)
	}
	if api.currentTheme() != "another-adapter" {
		t.Fatal("another adapter's explicit selection was overwritten")
	}
}
