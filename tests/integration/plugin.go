package main

import (
	"bufio"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

type qmlRun struct {
	cmd   *exec.Cmd
	lines chan string
	log   *os.File
}

func (a *launcherAccount) qml(plugin, control, omarchy string, missing bool) (*qmlRun, error) {
	mode := "0"
	if missing {
		mode = "1"
	}
	cmd := a.cmd([]string{"QT_QPA_PLATFORM=offscreen", "QT_QUICK_BACKEND=software",
		"QS_DISABLE_FILE_WATCHER=1", "OMARCHY_PATH=" + omarchy,
		"PATH=" + filepath.Join(omarchy, "bin") + ":" + filepath.Join(a.home, "bin") + ":/usr/bin:/bin",
		"SYNCSHELL_WITHOUT_WEBUI=" + mode, "SYNCSHELL_TEST_CONTROL=" + control},
		"quickshell", "--no-color", "-p", filepath.Join(plugin, "shell.qml"))
	q := &qmlRun{cmd: cmd, lines: make(chan string, 256)}
	var err error
	q.log, err = os.Create(filepath.Join(a.root, "qml-"+mode+".log"))
	if err != nil {
		return nil, err
	}
	output, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	cmd.Stderr = cmd.Stdout
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	go func() {
		defer close(q.lines)
		scanner := bufio.NewScanner(output)
		for scanner.Scan() {
			line := scanner.Text()
			fmt.Fprintln(q.log, line)
			if strings.Contains(line, "PLUGIN_") {
				q.lines <- line
			}
		}
	}()
	return q, nil
}

func (q *qmlRun) wait(ctx context.Context, marker string) error {
	deadline, cancel := context.WithTimeout(ctx, 70*time.Second)
	defer cancel()
	for {
		select {
		case <-deadline.Done():
			return fmt.Errorf("QML did not report %s", marker)
		case line, ok := <-q.lines:
			if !ok {
				return errors.New("QML exited; inspect its test log")
			}
			if strings.Contains(line, "PLUGIN_FAILED") {
				return errors.New(line)
			}
			if strings.Contains(line, marker) {
				return nil
			}
		}
	}
}

func (q *qmlRun) stop() { q.cmd.Process.Signal(syscall.SIGTERM); q.cmd.Wait(); q.log.Close() }

func testPhase(phase string, values map[string]any) {
	if values == nil {
		values = map[string]any{}
	}
	values["phase"] = phase
	json.NewEncoder(os.Stdout).Encode(values)
}

func advance(input *bufio.Scanner, want string) error {
	if !input.Scan() || input.Text() != want {
		return fmt.Errorf("expected test command %s", want)
	}
	return nil
}

func paletteBackground(theme string) (string, error) {
	data, err := exec.Command("omarchy-theme-color", "--file", theme, "background").Output()
	return strings.TrimSpace(string(data)), err
}

func runPlugin(ctx context.Context, root, source, qmlFile, omarchy string, port int) (err error) {
	a, err := newLauncherAccount(root, filepath.Join(source, "bin/x86_64/syncshell-core"))
	if a != nil {
		defer func() { err = errors.Join(err, a.cleanup()) }()
	}
	if err != nil {
		return err
	}
	d, err := a.prepare(ctx, port)
	if err != nil {
		return err
	}
	plugin := filepath.Join(a.home, ".config/omarchy/plugins/io.github.ilyazar.syncthing")
	if err := copyTree(source, plugin); err != nil {
		return err
	}
	for _, name := range []string{"Commons", "Ui"} {
		if err := os.Symlink(filepath.Join(omarchy, "shell", name), filepath.Join(plugin, name)); err != nil {
			return err
		}
	}
	fixture, err := os.ReadFile(qmlFile)
	if err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(plugin, "shell.qml"), fixture, 0644); err != nil {
		return err
	}
	settings := filepath.Join(a.home, ".config/omarchy/ilyazar.syncthing")
	if err := os.MkdirAll(settings, 0755); err != nil {
		return err
	}
	data, err := os.ReadFile(filepath.Join(plugin, "hosts/omarchy/config/settings.toml"))
	if err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(settings, "settings.toml"), data, 0644); err != nil {
		return err
	}
	themeDir := filepath.Join(a.home, ".local/state/omarchy/current/theme")
	if err := os.MkdirAll(themeDir, 0755); err != nil {
		return err
	}
	startTheme := filepath.Join(omarchy, "themes/tokyo-night/colors.toml")
	endTheme := filepath.Join(omarchy, "themes/white/colors.toml")
	palette, err := os.ReadFile(startTheme)
	if err != nil {
		return err
	}
	colors := filepath.Join(themeDir, "colors.toml")
	if err := os.WriteFile(colors, palette, 0644); err != nil {
		return err
	}
	control := filepath.Join(a.root, "control")
	if err := os.WriteFile(control, []byte("wait"), 0644); err != nil {
		return err
	}
	if err := command("chown", "-R", a.user+":"+a.user, a.home); err != nil {
		return err
	}
	q, err := a.qml(plugin, control, omarchy, false)
	if err != nil {
		return err
	}
	defer func() {
		if q != nil {
			q.stop()
		}
	}()
	if err := q.wait(ctx, "PLUGIN_READY"); err != nil {
		return err
	}
	var paths map[string]string
	if err := d.api(ctx, "GET", "system/paths", nil, &paths); err != nil {
		return err
	}
	gui := filepath.Clean(paths["guiAssets"])
	if !strings.HasPrefix(gui, a.home+string(os.PathSeparator)) {
		return errors.New("GUI assets escaped the test account")
	}
	versionPath := filepath.Join(gui, "syncthing-omarchy/theme-version.txt")
	before, err := os.ReadFile(versionPath)
	if err != nil {
		return err
	}
	background, err := paletteBackground(startTheme)
	if err != nil {
		return err
	}
	testPhase("ready", map[string]any{"url": "http://" + d.address, "background": background})
	input := bufio.NewScanner(os.Stdin)
	if err := advance(input, "theme"); err != nil {
		return err
	}
	palette, err = os.ReadFile(endTheme)
	if err != nil {
		return err
	}
	if err := os.WriteFile(colors+".new", palette, 0644); err != nil {
		return err
	}
	if err := os.Rename(colors+".new", colors); err != nil {
		return err
	}
	if err := a.run("quickshell", "ipc", "--path", filepath.Join(plugin, "shell.qml"),
		"--any-display", "call", "shell", "applyTheme", base64.StdEncoding.EncodeToString(palette), ""); err != nil {
		return err
	}
	background, err = paletteBackground(endTheme)
	if err != nil {
		return err
	}
	deadline := time.Now().Add(10 * time.Second)
	for {
		after, _ := os.ReadFile(versionPath)
		css, _ := os.ReadFile(filepath.Join(gui, "syncthing-omarchy/assets/css/omarchy_syncthing_theme.css"))
		if string(after) != string(before) && strings.Contains(string(css), "background-color: "+background) {
			break
		}
		if time.Now().After(deadline) {
			return errors.New("QML theme change did not regenerate the Web UI")
		}
		time.Sleep(100 * time.Millisecond)
	}
	background, err = paletteBackground(endTheme)
	if err != nil {
		return err
	}
	testPhase("theme", map[string]any{"background": background})
	if err := advance(input, "scan"); err != nil {
		return err
	}
	if err := pluginScan(ctx, a, d, q, control, "with-webui"); err != nil {
		return err
	}
	q.stop()
	q = nil
	if err := os.Rename(filepath.Join(plugin, "webui"), filepath.Join(a.root, "held-webui")); err != nil {
		return err
	}
	if err := os.Rename(gui, filepath.Join(a.root, "held-gui")); err != nil {
		return err
	}
	if err := os.WriteFile(control, []byte("wait"), 0644); err != nil {
		return err
	}
	q, err = a.qml(plugin, control, omarchy, true)
	if err != nil {
		return err
	}
	if err := q.wait(ctx, "PLUGIN_READY"); err != nil {
		return err
	}
	if err := pluginScan(ctx, a, d, q, control, "without-webui"); err != nil {
		return err
	}
	q.stop()
	q = nil
	testPhase("complete", map[string]any{"checks": []string{"actual Omarchy Color signal regenerates CSS", "actual QML rescan reaches Syncthing", "cold QML service works without bundled or prepared Web UI files"}})
	return nil
}

func pluginScan(ctx context.Context, a *launcherAccount, d *testDaemon, q *qmlRun, control, label string) error {
	var before, after struct{ LocalFiles int }
	if err := d.api(ctx, "GET", "db/status?folder=launcher-test", nil, &before); err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(a.home, "files", label+".txt"), []byte("QML rescan proof\n"), 0644); err != nil {
		return err
	}
	if err := os.WriteFile(control, []byte("rescan"), 0644); err != nil {
		return err
	}
	if err := q.wait(ctx, "PLUGIN_SCAN_OK"); err != nil {
		return err
	}
	if err := d.api(ctx, "GET", "db/status?folder=launcher-test", nil, &after); err != nil {
		return err
	}
	if after.LocalFiles != before.LocalFiles+1 {
		return errors.New("QML rescan did not index the file")
	}
	return nil
}
