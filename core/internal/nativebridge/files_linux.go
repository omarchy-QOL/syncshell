package nativebridge

import (
	"errors"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"syscall"

	"github.com/omarchy-QOL/syncshell/core/internal/protocol"
	"golang.org/x/sys/unix"
)

var fileName = regexp.MustCompile(`^request-[a-zA-Z0-9_-]{1,100}\.json$`)
var generationName = regexp.MustCompile(`^generation-[0-9]+$`)

func privateDirectory(path string) error {
	if !filepath.IsAbs(path) || filepath.Clean(path) != path {
		return errors.New("native runtime path must be absolute and clean")
	}
	real, err := filepath.EvalSymlinks(path)
	if err != nil || real != path {
		return errors.New("native runtime path must not contain symlinks")
	}
	info, err := os.Lstat(path)
	if err != nil || !info.IsDir() || info.Mode().Perm() != 0o700 ||
		info.Sys().(*syscall.Stat_t).Uid != uint32(os.Geteuid()) {
		return errors.New("native runtime directory must be owned by this user with mode 0700")
	}
	return nil
}

func openPrivateFile(path string, flags int) (*os.File, error) {
	fd, err := unix.Open(path, flags|unix.O_CLOEXEC|unix.O_NOFOLLOW|unix.O_NONBLOCK, 0o600)
	if err != nil {
		return nil, errors.New("cannot open private native file")
	}
	f := os.NewFile(uintptr(fd), path)
	info, err := f.Stat()
	if err != nil || !info.Mode().IsRegular() || info.Mode().Perm() != 0o600 {
		f.Close()
		return nil, errors.New("native file must be regular with mode 0600")
	}
	stat := info.Sys().(*syscall.Stat_t)
	if stat.Uid != uint32(os.Geteuid()) || stat.Nlink != 1 {
		f.Close()
		return nil, errors.New("native file ownership is invalid")
	}
	return f, nil
}

func consumeRequest(directory, name string) ([]byte, error) {
	if !fileName.MatchString(name) {
		return nil, errors.New("invalid native request filename")
	}
	path := filepath.Join(directory, name)
	f, err := openPrivateFile(path, unix.O_RDONLY)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	data, err := io.ReadAll(io.LimitReader(f, protocol.MaxLineBytes+1))
	if err != nil || len(data) == 0 || len(data) >= protocol.MaxLineBytes {
		return nil, errors.New("native request exceeds frame bound")
	}
	opened, _ := f.Stat()
	current, err := os.Lstat(path)
	if err != nil || !os.SameFile(opened, current) {
		return nil, errors.New("native request file changed")
	}
	if err := os.Remove(path); err != nil {
		return nil, errors.New("cannot consume native request")
	}
	return data, nil
}

// The lifetime lock is held while reclaiming directories from a crashed worker.
func cleanGenerations(base string) error {
	entries, err := os.ReadDir(base)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if !generationName.MatchString(entry.Name()) {
			continue
		}
		path := filepath.Join(base, entry.Name())
		if err := privateDirectory(path); err != nil {
			return err
		}
		children, err := os.ReadDir(path)
		if err != nil {
			return err
		}
		for _, child := range children {
			if child.Name() != "inlet.sock" && !fileName.MatchString(child.Name()) {
				return errors.New("unexpected file in native runtime directory")
			}
			info, err := child.Info()
			if err != nil || info.IsDir() || info.Mode()&os.ModeSymlink != 0 ||
				info.Sys().(*syscall.Stat_t).Uid != uint32(os.Geteuid()) {
				return errors.New("unsafe native runtime cleanup target")
			}
			if err := os.Remove(filepath.Join(path, child.Name())); err != nil {
				return err
			}
		}
		if err := os.Remove(path); err != nil {
			return err
		}
	}
	return nil
}
