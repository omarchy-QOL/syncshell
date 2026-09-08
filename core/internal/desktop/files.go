package desktop

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
	"golang.org/x/sys/unix"
)

var conflictMarker = regexp.MustCompile(`^(.*)\.sync-conflict-[0-9]{8}-[0-9]{6}-[A-Z2-7]{7}(\..*)?$`)

func originalPath(path string) string {
	match := conflictMarker.FindStringSubmatch(filepath.Base(path))
	if match == nil {
		return ""
	}
	name := match[1] + match[2]
	if name == "" || conflictMarker.MatchString(name) {
		return ""
	}
	return filepath.Join(filepath.Dir(path), name)
}

func (b *Bridge) action(ctx context.Context, action string, body request) (any, error) {
	if action != "status" && action != "check" && action != "open" && action != "rename" {
		return nil, errors.New("unsupported desktop action")
	}
	status, err := b.client.Status(ctx)
	if err != nil {
		return nil, err
	}
	if body.Device == "" || body.Device != status.MyID {
		return nil, errors.New("Syncthing identity changed; reopen the Web UI from the plugin")
	}
	if err := b.localProcess(); err != nil {
		return nil, err
	}
	paths, err := b.client.SystemPaths(ctx)
	if err != nil {
		return nil, err
	}
	selected, selectedErr := filepath.EvalSymlinks(b.client.Target().ConfigPath)
	reported, reportedErr := filepath.EvalSymlinks(paths.Config)
	if selectedErr != nil || reportedErr != nil || selected != reported {
		return nil, errors.New("local Syncthing configuration could not be verified")
	}
	if action == "status" {
		return map[string]bool{"available": true}, nil
	}
	folder, err := b.client.Folder(ctx, body.Folder)
	if err != nil {
		return nil, err
	}
	return b.fileAction(ctx, action, body, folder, status.Tilde)
}

func (b *Bridge) fileAction(ctx context.Context, action string, body request, folder syncthing.Folder, home string) (any, error) {
	root, err := localFolderPath(folder.Path, body.Root, home)
	if err != nil {
		return nil, err
	}
	if !filepath.IsLocal(body.Path) || !filepath.IsLocal(body.File) ||
		strings.ContainsRune(body.File, 0) || strings.ContainsRune(body.Path, 0) ||
		(body.File != body.Path && originalPath(body.File) != body.Path) {
		return nil, errors.New("file is not part of the selected conflict")
	}
	fd, err := openDirectory(root, filepath.Dir(body.File))
	if err != nil {
		return nil, fmt.Errorf("folder is unavailable to this desktop: %w", err)
	}
	defer unix.Close(fd)
	var file unix.Stat_t
	if err := unix.Fstatat(fd, filepath.Base(body.File), &file, unix.AT_SYMLINK_NOFOLLOW); err != nil {
		return nil, errors.New("file is no longer available locally; recheck the list")
	}
	if file.Mode&unix.S_IFMT != unix.S_IFREG {
		return nil, errors.New("desktop actions require a regular file, without symlinks")
	}
	if action == "check" {
		writeErr := unix.Faccessat(fd, ".", unix.W_OK|unix.X_OK, unix.AT_EACCESS)
		reason := ""
		if writeErr != nil {
			reason = "This desktop user cannot rename files in this folder."
		}
		return map[string]any{"open": true, "rename": writeErr == nil, "reason": reason}, nil
	}
	if action == "open" {
		return map[string]bool{"opened": true}, b.launch(ctx, filepath.Join(root, filepath.Dir(body.File)))
	}
	return renameConflict(fd, body, file)
}

func localFolderPath(configured, requested, home string) (string, error) {
	if configured != requested {
		return "", errors.New("folder path changed; recheck the file list")
	}
	root := configured
	if root == "~" || strings.HasPrefix(root, "~/") {
		root = filepath.Join(home, strings.TrimPrefix(root, "~"))
	}
	if !filepath.IsAbs(root) {
		return "", errors.New("desktop actions require an absolute Syncthing folder path")
	}
	return root, nil
}

func renameConflict(fd int, body request, file unix.Stat_t) (any, error) {
	if originalPath(body.File) != body.Path {
		return nil, errors.New("only a Syncthing conflict filename can be restored")
	}
	if file.Size != body.Size || file.Mtim.Sec != body.Modified.Unix() ||
		file.Mtim.Nsec != int64(body.Modified.Nanosecond()) {
		return nil, errors.New("the conflict file changed; recheck before renaming")
	}
	// The directory descriptor and no-replace rename prevent path redirection and replacement.
	if err := unix.Renameat2(fd, filepath.Base(body.File), fd, filepath.Base(body.Path), unix.RENAME_NOREPLACE); err != nil {
		if errors.Is(err, unix.EEXIST) {
			return nil, errors.New("the original name already exists; no file was replaced")
		}
		return nil, fmt.Errorf("could not rename the conflict file: %w", err)
	}
	return map[string]bool{"renamed": true}, nil
}

// Do not follow a folder or intermediate symlink into unrelated files.
func openDirectory(root, relative string) (int, error) {
	fd, err := unix.Open("/", unix.O_RDONLY|unix.O_DIRECTORY|unix.O_CLOEXEC, 0)
	if err != nil {
		return -1, err
	}
	for _, part := range strings.Split(filepath.Join(root, relative), "/") {
		if part == "" || part == "." {
			continue
		}
		next, err := unix.Openat(fd, part, unix.O_RDONLY|unix.O_DIRECTORY|unix.O_NOFOLLOW|unix.O_CLOEXEC, 0)
		unix.Close(fd)
		if err != nil {
			return -1, err
		}
		fd = next
	}
	return fd, nil
}
