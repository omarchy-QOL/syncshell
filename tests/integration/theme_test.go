package main

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestReviewPaletteFollowsDesktopFile(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	colors := filepath.Join(home, ".local/state/omarchy/current/theme/colors.toml")
	if err := os.MkdirAll(filepath.Dir(colors), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(colors, []byte("first"), 0600); err != nil {
		t.Fatal(err)
	}
	helper := filepath.Join(home, "prepare.sh")
	if err := os.WriteFile(helper, []byte("#!/bin/bash\nset -e\ncp \"$HOME/.local/state/omarchy/current/theme/colors.toml\" \"$3/palette\"\n"), 0600); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	if err := followReviewTheme(ctx, helper, home); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(colors, []byte("second"), 0600); err != nil {
		t.Fatal(err)
	}
	deadline := time.Now().Add(4 * time.Second)
	for {
		data, err := os.ReadFile(filepath.Join(home, "palette"))
		if err == nil && string(data) == "second" {
			return
		}
		if time.Now().After(deadline) {
			t.Fatal("review palette did not update")
		}
		time.Sleep(20 * time.Millisecond)
	}
}
