package main

import (
	"context"
	"crypto/sha256"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

// Review instances do not receive the installed shell's theme IPC.
func followReviewTheme(helper, assets string) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	colors := filepath.Join(home, ".local/state/omarchy/current/theme/colors.toml")
	prepare := func() ([32]byte, error) {
		data, err := os.ReadFile(colors)
		if err != nil {
			return [32]byte{}, err
		}
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		err = exec.CommandContext(ctx, "bash", helper, "prepare", "omarchy", assets).Run()
		return sha256.Sum256(data), err
	}
	previous, err := prepare()
	if err != nil {
		return err
	}
	go func() {
		ticker := time.NewTicker(time.Second)
		defer ticker.Stop()
		for range ticker.C {
			data, err := os.ReadFile(colors)
			if err != nil || sha256.Sum256(data) == previous {
				continue
			}
			previous, err = prepare()
			if err != nil {
				log.Print("review palette preparation failed: ", err)
			}
		}
	}()
	return nil
}
