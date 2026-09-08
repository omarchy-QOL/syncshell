package syncthing

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

func TestDiscoverSyncThingy(t *testing.T) {
	for _, location := range []string{".local/state", "config"} {
		t.Run(location, func(t *testing.T) {
			options := isolatedDiscovery(t)
			path := filepath.Join(options.Home, ".var/app/com.github.zocker_160.SyncThingy",
				location, "syncthing/config.xml")
			writeConfig(t, path, "127.0.0.1:9384", false)
			target, err := Discover(context.Background(), options)
			if err != nil {
				t.Fatal(err)
			}
			if target.ConfigPath != path || target.Endpoint != "http://127.0.0.1:9384" ||
				target.apiKey != testAPIKey || !target.Local || target.Automatic {
				t.Fatalf("incorrect Flatpak target or native-service authority: %#v", target)
			}
		})
	}
}

func TestSyncThingyDiscoveryPrecedence(t *testing.T) {
	options := isolatedDiscovery(t)
	paths := syncThingyConfigPaths(options.Home)
	for _, path := range paths {
		writeConfig(t, path, "127.0.0.1:9384", false)
	}
	_, err := Discover(context.Background(), options)
	assertErrorCode(t, err, ErrorAmbiguous)

	options.ConfigPath = paths[1]
	target, err := Discover(context.Background(), options)
	if err != nil || target.ConfigPath != paths[1] {
		t.Fatalf("explicit selection did not resolve ambiguity: %#v %v", target, err)
	}
	options.ConfigPath = ""
	native := filepath.Join(options.Home, ".local/state/syncthing/config.xml")
	writeConfig(t, native, "127.0.0.1:8384", false)
	target, err = Discover(context.Background(), options)
	if err != nil || target.ConfigPath != native || !target.Automatic {
		t.Fatalf("Flatpak changed native precedence: %#v %v", target, err)
	}
}

func TestSyncThingyConfigValidation(t *testing.T) {
	options := isolatedDiscovery(t)
	path := syncThingyConfigPaths(options.Home)[0]
	writeConfig(t, path, "127.0.0.1:9384", true)
	_, err := Discover(context.Background(), options)
	assertErrorCode(t, err, ErrorTLS)
	certificate := filepath.Join(filepath.Dir(path), "https-cert.pem")
	if err := os.WriteFile(certificate, []byte("certificate parsed by the client"), 0o600); err != nil {
		t.Fatal(err)
	}
	target, err := Discover(context.Background(), options)
	if err != nil || target.Endpoint != "https://127.0.0.1:9384" || target.tlsCertificate != certificate {
		t.Fatalf("Flatpak TLS configuration was lost: %#v %v", target, err)
	}
	if err := os.WriteFile(path, []byte("<configuration>"), 0o600); err != nil {
		t.Fatal(err)
	}
	_, err = Discover(context.Background(), options)
	assertErrorCode(t, err, ErrorConfig)
}

func isolatedDiscovery(t *testing.T) DiscoveryOptions {
	t.Helper()
	for _, key := range []string{"STCONFDIR", "STHOMEDIR", "XDG_CONFIG_HOME", "XDG_STATE_HOME"} {
		t.Setenv(key, "")
	}
	home := t.TempDir()
	return DiscoveryOptions{Home: home, SyncthingBinary: filepath.Join(home, "missing-syncthing")}
}
