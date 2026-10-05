package waybarconfig

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"strings"
	"testing"
)

func writeTestFile(t *testing.T, path, text string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(text), 0o600); err != nil {
		t.Fatal(err)
	}
}

func readTestFile(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func TestInstallRemovePreservesUserSettings(t *testing.T) {
	for _, modules := range []string{`"modules-right": ["tray"],`, `"modules-right": [],`, ""} {
		t.Run(modules, func(t *testing.T) {
			root := t.TempDir()
			config, style := filepath.Join(root, "config.jsonc"), filepath.Join(root, "style.css")
			original := "{\n  // unrelated comment\n  " + modules +
				"\n  \"position\": \"bottom\",\n  \"clock\": {\"format\": \"{:%H:%M}\"}\n}\n"
			originalStyle := "#clock { color: white; }\n"
			writeTestFile(t, config, original)
			writeTestFile(t, style, originalStyle)
			for i := 0; i < 2; i++ {
				if err := Run([]string{"install", "--config", config, "--style", style, "--root", root}); err != nil {
					t.Fatal(err)
				}
			}
			installed := readTestFile(t, config)
			for _, marker := range []string{moduleStart, placementStart} {
				if strings.Count(installed, marker) != 1 {
					t.Fatalf("duplicate or missing marker %s", marker)
				}
			}
			if strings.Count(readTestFile(t, style), styleStart) != 1 {
				t.Fatal("duplicate style import")
			}
			withoutComments := regexp.MustCompile(`(?m)//[^\n]*`).ReplaceAllString(installed, "")
			if !json.Valid([]byte(withoutComments)) {
				t.Fatalf("invalid installed JSONC: %s", installed)
			}
			if readTestFile(t, filepath.Join(root, "position")) != "bottom\n" {
				t.Fatal("bar position lost")
			}
			for i := 0; i < 2; i++ {
				if err := Run([]string{"remove", "--config", config, "--style", style, "--root", root}); err != nil {
					t.Fatal(err)
				}
			}
			removed := readTestFile(t, config)
			if strings.Contains(removed, "syncshell") ||
				!strings.Contains(removed, "// unrelated comment") ||
				!strings.Contains(removed, `"clock": {"format": "{:%H:%M}"}`) {
				t.Fatalf("user config changed: %s", removed)
			}
			comments := regexp.MustCompile(`(?m)//[^\n]*`)
			var before, after any
			if err := json.Unmarshal([]byte(comments.ReplaceAllString(original, "")), &before); err != nil {
				t.Fatal(err)
			}
			if err := json.Unmarshal([]byte(comments.ReplaceAllString(removed, "")), &after); err != nil {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(before, after) {
				t.Fatalf("user settings changed: %s", removed)
			}
			if readTestFile(t, style) != originalStyle {
				t.Fatal("user CSS changed")
			}
			for _, path := range []string{config, style} {
				info, err := os.Stat(path)
				if err != nil || info.Mode().Perm() != 0o600 {
					t.Fatalf("permissions changed: %s", path)
				}
			}
		})
	}
}

func TestMissingFiles(t *testing.T) {
	root := filepath.Join(t.TempDir(), "new")
	config, style := filepath.Join(root, "config.jsonc"), filepath.Join(root, "style.css")
	if err := update("remove", config, style, root); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(root); !os.IsNotExist(err) {
		t.Fatal("removal created missing files")
	}
	if err := update("install", config, style, root); err != nil {
		t.Fatal(err)
	}
	if readTestFile(t, filepath.Join(root, "position")) != "top\n" {
		t.Fatal("incorrect default position")
	}
}

func TestInvalidBlocksLeaveFilesUntouched(t *testing.T) {
	for _, broken := range []string{moduleStart, moduleEnd, placementStart, styleStart} {
		t.Run(broken, func(t *testing.T) {
			root := t.TempDir()
			config, style := filepath.Join(root, "config"), filepath.Join(root, "style")
			originalConfig, originalStyle := "{}\n", "#clock {}\n"
			if broken == styleStart {
				originalStyle += broken
			} else {
				originalConfig += broken
			}
			writeTestFile(t, config, originalConfig)
			writeTestFile(t, style, originalStyle)
			for _, action := range []string{"install", "remove"} {
				if err := update(action, config, style, root); err == nil {
					t.Fatal("accepted incomplete block")
				}
				if readTestFile(t, config) != originalConfig || readTestFile(t, style) != originalStyle {
					t.Fatal("invalid input modified user files")
				}
			}
		})
	}
}

func TestRejectsInvalidArguments(t *testing.T) {
	for _, args := range [][]string{nil, {"unknown"}, {"install"},
		{"remove", "--bad"}, {"install", "--config", "a", "--style", "b", "--root", "c", "extra"}} {
		if err := Run(args); err == nil {
			t.Fatalf("accepted %q", args)
		}
	}
}

func TestShellQuote(t *testing.T) {
	for value, want := range map[string]string{
		"/tmp/adapter":       "/tmp/adapter",
		"/tmp/my adapter":    "'/tmp/my adapter'",
		"/tmp/it's here":     "'/tmp/it'\"'\"'s here'",
		"/tmp/$(touch nope)": "'/tmp/$(touch nope)'",
	} {
		if got := shellQuote(value); got != want {
			t.Fatalf("shellQuote(%q) = %q, want %q", value, got, want)
		}
	}
}
