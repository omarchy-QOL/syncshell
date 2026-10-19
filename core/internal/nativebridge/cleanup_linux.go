package nativebridge

import (
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"strings"
)

// SaveCleanup leaves an owned recovery command outside the removable package.
func SaveCleanup(dataDirectory string, args []string) error {
	directory := filepath.Join(dataDirectory, "syncshell-noctalia-cleanup")
	err := os.Mkdir(directory, 0o700)
	created := err == nil
	if err != nil && !os.IsExist(err) {
		return errors.New("cannot create cleanup directory")
	}
	if err := privateDirectory(directory); err != nil {
		return err
	}
	marker := filepath.Join(directory, ".owner")
	if created {
		if err := os.WriteFile(marker, []byte("noctalia\n"), 0o600); err != nil {
			return err
		}
	} else if data, err := os.ReadFile(marker); err != nil || string(data) != "noctalia\n" {
		return errors.New("cleanup directory is not owned by Noctalia")
	}
	executable, err := os.Executable()
	if err != nil {
		return err
	}
	data, err := os.ReadFile(executable)
	if err != nil {
		return err
	}
	if err := replaceCleanupFile(directory, "syncshell-core", data, 0o700); err != nil {
		return err
	}
	quote := func(value string) string { return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'" }
	command := "#!/bin/sh\nexec " + quote(filepath.Join(directory, "syncshell-core")) + " profile-cleanup --json"
	for _, arg := range args {
		if strings.ContainsRune(arg, 0) {
			return errors.New("invalid cleanup argument")
		}
		command += " " + quote(arg)
	}
	return replaceCleanupFile(directory, "cleanup.sh", []byte(command+"\n"), 0o700)
}

func replaceCleanupFile(directory, name string, data []byte, mode os.FileMode) error {
	path := filepath.Join(directory, name)
	if info, err := os.Lstat(path); err == nil {
		if !info.Mode().IsRegular() {
			return errors.New("cleanup file is not regular")
		}
		if previous, err := os.ReadFile(path); err == nil && bytes.Equal(data, previous) {
			return nil
		}
	}
	file, err := os.CreateTemp(directory, ".cleanup-")
	if err != nil {
		return err
	}
	defer os.Remove(file.Name())
	if _, err := file.Write(data); err != nil {
		file.Close()
		return err
	}
	if err := file.Chmod(mode); err != nil {
		file.Close()
		return err
	}
	if err := file.Close(); err != nil {
		return err
	}
	return os.Rename(file.Name(), path)
}
