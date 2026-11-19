package webprofile

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func policy(t *testing.T) Policy {
	t.Helper()
	bundle, err := filepath.Abs("../../../webui")
	if err != nil {
		t.Fatal(err)
	}
	return Policy{Authorized: true, Owner: "test-host", Bundle: bundle}
}

func palette() map[string]string {
	return map[string]string{
		"mode": "dark", "background": "#101010", "surface": "#202020",
		"surfaceVariant": "#303030", "foreground": "#eeeeee", "muted": "#aaaaaa",
		"accent": "#8888ff", "success": "#88ff88", "warning": "#ffff88",
		"danger": "#ff8888", "border": "#444444", "info": "#88ffff",
	}
}

func TestProfilesInstallUpdateAndOwnedCleanup(t *testing.T) {
	p := policy(t)
	assets := filepath.Join(t.TempDir(), "gui")
	for _, style := range []string{"modern", "themed"} {
		name, err := p.Prepare(assets, style, palette())
		if err != nil {
			t.Fatal(err)
		}
		if _, err := os.Stat(filepath.Join(assets, name, "index.html")); err != nil {
			t.Fatal(err)
		}
		if style == "themed" {
			css, err := os.ReadFile(filepath.Join(assets, name, "assets/css/omarchy_syncthing_theme.css"))
			if err != nil || strings.Contains(string(css), "{{") || !strings.Contains(string(css), "#101010") {
				t.Fatalf("palette was not rendered: %v", err)
			}
			updated := palette()
			updated["background"] = "#121212"
			if _, err := p.Prepare(assets, style, updated); err != nil {
				t.Fatal(err)
			}
			css, _ = os.ReadFile(filepath.Join(assets, name, "assets/css/omarchy_syncthing_theme.css"))
			if !strings.Contains(string(css), "#121212") {
				t.Fatal("existing owned palette was not replaced")
			}
		}
	}
	other := filepath.Join(assets, "another-adapter")
	if err := os.Mkdir(other, 0700); err != nil {
		t.Fatal(err)
	}
	if err := p.Remove(assets); err != nil {
		t.Fatal(err)
	}
	entries, _ := os.ReadDir(assets)
	if len(entries) != 1 || entries[0].Name() != "another-adapter" {
		t.Fatalf("cleanup changed other resources: %v", entries)
	}
}

func TestProfilesRejectForeignTargetsAndLinks(t *testing.T) {
	p := policy(t)
	assets := t.TempDir()
	name, _ := p.Name("modern")
	target := filepath.Join(assets, name)
	if err := os.Mkdir(target, 0700); err != nil {
		t.Fatal(err)
	}
	if _, err := p.Prepare(assets, "modern", nil); err == nil {
		t.Fatal("unowned directory was overwritten")
	}
	if err := p.Remove(assets); err == nil {
		t.Fatal("unowned directory was removed")
	}
	linkedAssets := filepath.Join(t.TempDir(), "linked")
	if err := os.Symlink(assets, linkedAssets); err != nil {
		t.Fatal(err)
	}
	if _, err := p.Prepare(linkedAssets, "modern", nil); err == nil {
		t.Fatal("linked assets were accepted")
	}
	p.Authorized = false
	if _, err := p.Prepare(assets, "modern", nil); err == nil {
		t.Fatal("missing authority was accepted")
	}
}

func TestProfilesReadThroughLinkedPluginDirectory(t *testing.T) {
	p := policy(t)
	installed := filepath.Join(t.TempDir(), "syncshell")
	if err := os.Symlink(filepath.Dir(p.Bundle), installed); err != nil {
		t.Fatal(err)
	}
	p.Bundle = filepath.Join(installed, "webui")
	assets := t.TempDir()
	name, err := p.Prepare(assets, "themed", palette())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(assets, name, "index.html")); err != nil {
		t.Fatal(err)
	}
	if err := p.Remove(assets); err != nil {
		t.Fatal(err)
	}
}

func TestProfileBundleEntriesCannotRedirectOutsidePackage(t *testing.T) {
	p := policy(t)
	original := p.Bundle
	p.Bundle = t.TempDir()
	if err := os.Symlink(filepath.Join(original, "SHA256SUMS"),
		filepath.Join(p.Bundle, "SHA256SUMS")); err != nil {
		t.Fatal(err)
	}
	if _, err := p.Prepare(t.TempDir(), "modern", nil); err == nil {
		t.Fatal("linked checksum file inside the bundle was accepted")
	}
}

func TestProfilePaletteAndBundleValidation(t *testing.T) {
	p := policy(t)
	bad := palette()
	bad["accent"] = "red; background: url(https://invalid)"
	if _, err := p.Prepare(t.TempDir(), "themed", bad); err == nil {
		t.Fatal("invalid semantic color was accepted")
	}
	p.Bundle = t.TempDir()
	if err := os.WriteFile(filepath.Join(p.Bundle, "SHA256SUMS"),
		[]byte(strings.Repeat("0", 64)+"  ../escape\n"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := p.Prepare(t.TempDir(), "modern", nil); err == nil {
		t.Fatal("escaping bundle path was accepted")
	}
}
