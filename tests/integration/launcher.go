package main

import (
	"bufio"
	"context"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

type launcherAccount struct {
	root, home, user, uid, unit string
	created, manager            bool
}

func command(args ...string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if output, err := exec.CommandContext(ctx, args[0], args[1:]...).CombinedOutput(); err != nil {
		return fmt.Errorf("%s failed: %w: %s", args[0], err, strings.TrimSpace(string(output)))
	}
	return nil
}

func (a *launcherAccount) cmd(environment []string, args ...string) *exec.Cmd {
	base := []string{"-u", a.user, "--", "env", "-i", "HOME=" + a.home, "USER=" + a.user, "LOGNAME=" + a.user,
		"PATH=" + filepath.Join(a.home, "bin") + ":/usr/bin:/bin", "XDG_RUNTIME_DIR=/run/user/" + a.uid,
		"DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/" + a.uid + "/bus",
		"XDG_CONFIG_HOME=" + filepath.Join(a.home, ".config"), "XDG_STATE_HOME=" + filepath.Join(a.home, ".local/state")}
	base = append(base, environment...)
	base = append(base, args...)
	return exec.Command("runuser", base...)
}

func (a *launcherAccount) run(args ...string) error {
	if output, err := a.cmd(nil, args...).CombinedOutput(); err != nil {
		return fmt.Errorf("%s failed: %w: %s", args[0], err, strings.TrimSpace(string(output)))
	}
	return nil
}

func (a *launcherAccount) cleanup() error {
	if !a.created {
		return nil
	}
	output, err := exec.Command("getent", "passwd", a.user).Output()
	if err != nil {
		return err
	}
	parts := strings.Split(strings.TrimSpace(string(output)), ":")
	if len(parts) != 7 || parts[2] != a.uid || parts[5] != a.home {
		return errors.New("test account identity changed; refusing cleanup")
	}
	if _, err := os.Stat(filepath.Join("/run/systemd/system", a.unit)); err == nil {
		if err := command("systemctl", "stop", a.unit); err != nil {
			return err
		}
		if err := os.Remove(filepath.Join("/run/systemd/system", a.unit)); err != nil {
			return err
		}
		if err := command("systemctl", "daemon-reload"); err != nil {
			return err
		}
	}
	if a.manager {
		if err := command("loginctl", "disable-linger", a.user); err != nil {
			return err
		}
		if err := command("systemctl", "stop", "user@"+a.uid+".service"); err != nil {
			return err
		}
	}
	if err := command("userdel", a.user); err != nil {
		return err
	}
	a.created = false
	return nil
}

func newLauncherAccount(root, core string) (*launcherAccount, error) {
	if os.Geteuid() != 0 {
		return nil, errors.New("launcher acceptance needs root to create an isolated test account")
	}
	if !filepath.IsAbs(root) {
		return nil, errors.New("launcher runtime path must be absolute")
	}
	if err := os.Mkdir(root, 0755); err != nil {
		return nil, err
	}
	a := &launcherAccount{root: root, home: filepath.Join(root, "home"), user: "syncshell-test-" + strconv.Itoa(os.Getpid())}
	a.unit = a.user + ".service"
	if err := os.Mkdir(filepath.Join(root, "empty-skel"), 0755); err != nil {
		return nil, err
	}
	if err := command("useradd", "--system", "--user-group", "--create-home", "--skel", filepath.Join(root, "empty-skel"), "--home-dir", a.home, "--shell", "/bin/bash", a.user); err != nil {
		return nil, err
	}
	a.created = true
	uid, err := exec.Command("id", "-u", a.user).Output()
	if err != nil {
		return a, err
	}
	a.uid = strings.TrimSpace(string(uid))
	if err := os.MkdirAll(filepath.Join(a.home, "bin"), 0755); err != nil {
		return a, err
	}
	syncthing, err := exec.LookPath("syncthing")
	if err != nil {
		return a, err
	}
	for name, source := range map[string]string{"syncshell-core": core, "syncthing": syncthing} {
		data, err := os.ReadFile(source)
		if err != nil {
			return a, err
		}
		if err := os.WriteFile(filepath.Join(a.home, "bin", name), data, 0755); err != nil {
			return a, err
		}
	}
	if err := command("chown", "-R", a.user+":"+a.user, a.home); err != nil {
		return a, err
	}
	if err := command("loginctl", "enable-linger", a.user); err != nil {
		return a, err
	}
	a.manager = true
	if err := command("systemctl", "start", "user@"+a.uid+".service"); err != nil {
		return a, err
	}
	return a, nil
}

func (a *launcherAccount) prepare(ctx context.Context, port int) (*testDaemon, error) {
	if err := a.run("syncthing", "generate", "--no-port-probing"); err != nil {
		return nil, err
	}
	configPath := filepath.Join(a.home, ".local/state/syncthing/config.xml")
	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, err
	}
	address := "127.0.0.1:" + strconv.Itoa(port)
	data, err = fixtureConfig(data, address, "tcp://127.0.0.1:0")
	if err != nil {
		return nil, err
	}
	if err := os.WriteFile(configPath, data, 0600); err != nil {
		return nil, err
	}
	var config struct {
		GUI struct {
			Key string `xml:"apikey"`
		} `xml:"gui"`
	}
	if err := xml.Unmarshal(data, &config); err != nil {
		return nil, err
	}
	unitDir := filepath.Join(a.home, ".config/systemd/user")
	if err := os.MkdirAll(unitDir, 0755); err != nil {
		return nil, err
	}
	unit := "[Unit]\nDescription=Disposable Syncthing acceptance\n[Service]\nType=exec\nExecStart=" + filepath.Join(a.home, "bin/syncthing") + " serve --no-browser --no-restart --no-upgrade --no-port-probing\n[Install]\nWantedBy=default.target\n"
	if err := os.WriteFile(filepath.Join(unitDir, "syncthing.service"), []byte(unit), 0644); err != nil {
		return nil, err
	}
	systemUnit := strings.Replace(unit, "Type=exec\n", "Type=exec\nUser="+a.user+"\nEnvironment=HOME="+a.home+"\n", 1)
	if err := os.WriteFile(filepath.Join("/run/systemd/system", a.unit), []byte(systemUnit), 0644); err != nil {
		return nil, err
	}
	if err := command("chown", "-R", a.user+":"+a.user, a.home); err != nil {
		return nil, err
	}
	if err := a.run("systemctl", "--user", "daemon-reload"); err != nil {
		return nil, err
	}
	if err := a.run("systemctl", "--user", "disable", "--now", "syncthing.service"); err != nil {
		return nil, err
	}
	if err := command("systemctl", "daemon-reload"); err != nil {
		return nil, err
	}
	if err := command("systemctl", "start", a.unit); err != nil {
		return nil, err
	}
	d := &testDaemon{root: a.home, address: address, key: config.GUI.Key}
	if err := waitAPI(ctx, d); err != nil {
		return nil, err
	}
	var full, folder map[string]any
	if err := d.api(ctx, "GET", "config", nil, &full); err != nil {
		return nil, err
	}
	if err := d.api(ctx, "GET", "config/defaults/folder", nil, &folder); err != nil {
		return nil, err
	}
	files := filepath.Join(a.home, "files")
	if err := os.Mkdir(files, 0755); err != nil {
		return nil, err
	}
	if err := command("chown", a.user+":"+a.user, files); err != nil {
		return nil, err
	}
	folder["id"], folder["label"], folder["path"] = "launcher-test", "Launcher acceptance", files
	folder["fsWatcherEnabled"], folder["rescanIntervalS"] = false, 0
	full["folders"] = []any{folder}
	if err := d.api(ctx, "PUT", "config", full, nil); err != nil {
		return nil, err
	}
	if err := d.api(ctx, "POST", "db/scan?folder=launcher-test", nil, nil); err != nil {
		return nil, err
	}
	return d, nil
}

func waitAPI(ctx context.Context, d *testDaemon) error {
	deadline, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	for {
		if err := d.api(deadline, "GET", "system/status", nil, &map[string]any{}); err == nil {
			return nil
		}
		select {
		case <-deadline.Done():
			return errors.New("test Syncthing did not recover")
		case <-time.After(100 * time.Millisecond):
		}
	}
}

type coreFrame struct {
	Type, ID string
	OK       bool
	State    struct {
		Connection struct{ Online bool }
		Lifecycle  struct {
			Classification string
			CanControl     bool
		}
		Folders []struct{ ID string }
	}
}

type coreStream struct {
	cmd    *exec.Cmd
	input  io.WriteCloser
	frames chan coreFrame
	log    *os.File
	latest coreFrame
}

func (a *launcherAccount) core(environment ...string) (*coreStream, error) {
	cmd := a.cmd(environment, "syncshell-core", "stream", "--host-id", "omarchy", "--lifecycle-kind", "systemd-user", "--lifecycle-authorized", "--lifecycle-unit", "syncthing.service")
	s := &coreStream{cmd: cmd, frames: make(chan coreFrame, 256)}
	var err error
	s.input, err = cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	output, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	s.log, err = os.OpenFile(filepath.Join(a.root, "core.log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0600)
	if err != nil {
		return nil, err
	}
	cmd.Stderr = s.log
	if err := cmd.Start(); err != nil {
		s.log.Close()
		return nil, err
	}
	go func() {
		defer close(s.frames)
		scanner := bufio.NewScanner(output)
		scanner.Buffer(make([]byte, 65536), 4<<20)
		for scanner.Scan() {
			var frame coreFrame
			if json.Unmarshal(scanner.Bytes(), &frame) == nil {
				s.frames <- frame
			}
		}
	}()
	return s, nil
}

func (s *coreStream) close() { s.input.Close(); s.cmd.Wait(); s.log.Close() }

func (s *coreStream) await(ctx context.Context, predicate func(coreFrame) bool) (coreFrame, error) {
	deadline, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	var last coreFrame
	for {
		select {
		case <-deadline.Done():
			return coreFrame{}, fmt.Errorf("core acceptance timed out: last=%s online=%t launcher=%s folders=%d", last.Type, last.State.Connection.Online, last.State.Lifecycle.Classification, len(last.State.Folders))
		case frame, ok := <-s.frames:
			if !ok {
				return coreFrame{}, errors.New("core exited before acceptance completed")
			}
			last = frame
			if frame.Type == "snapshot" {
				s.latest = frame
			}
			if predicate(frame) {
				return frame, nil
			}
		}
	}
}

func (s *coreStream) action(ctx context.Context, id, action string, args any, wantOK bool) error {
	if err := json.NewEncoder(s.input).Encode(map[string]any{"v": 1, "type": "action", "id": id, "action": action, "args": args}); err != nil {
		return err
	}
	frame, err := s.await(ctx, func(f coreFrame) bool { return f.Type == "result" && f.ID == id })
	if err != nil {
		return err
	}
	if frame.OK != wantOK {
		return fmt.Errorf("unexpected result for %s", action)
	}
	return nil
}

func (s *coreStream) online(ctx context.Context, classification string) error {
	matches := func(f coreFrame) bool {
		return f.Type == "snapshot" && f.State.Connection.Online && f.State.Lifecycle.Classification == classification && len(f.State.Folders) == 1
	}
	if matches(s.latest) {
		return nil
	}
	_, err := s.await(ctx, matches)
	return err
}

func (a *launcherAccount) inactive() error {
	output, err := a.cmd(nil, "systemctl", "--user", "show", "syncthing.service", "-p", "ActiveState", "-p", "UnitFileState").Output()
	if err != nil {
		return err
	}
	if !strings.Contains(string(output), "ActiveState=inactive") || !strings.Contains(string(output), "UnitFileState=disabled") {
		return errors.New("external launcher changed the unrelated user unit")
	}
	return nil
}

func scanAcceptance(ctx context.Context, a *launcherAccount, d *testDaemon, s *coreStream, label string) error {
	var before, after struct{ LocalFiles int }
	if err := d.api(ctx, "GET", "db/status?folder=launcher-test", nil, &before); err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(a.home, "files", label+".txt"), []byte("tiny rescan proof\n"), 0644); err != nil {
		return err
	}
	if err := d.api(ctx, "GET", "db/status?folder=launcher-test", nil, &after); err != nil {
		return err
	}
	if before.LocalFiles != after.LocalFiles {
		return errors.New("fixture scanned before the requested action")
	}
	if err := s.action(ctx, "scan-"+label, "folder.rescan", map[string]string{"folderId": "launcher-test"}, true); err != nil {
		return err
	}
	if err := d.api(ctx, "GET", "db/status?folder=launcher-test", nil, &after); err != nil {
		return err
	}
	if after.LocalFiles != before.LocalFiles+1 {
		return errors.New("rescan did not index the test file")
	}
	return nil
}

func runLauncher(ctx context.Context, root, core string, port int) (err error) {
	a, err := newLauncherAccount(root, core)
	if a != nil {
		defer func() {
			if cleanupErr := a.cleanup(); cleanupErr != nil {
				err = errors.Join(err, cleanupErr)
			}
		}()
	}
	if err != nil {
		return err
	}
	d, err := a.prepare(ctx, port)
	if err != nil {
		return err
	}
	s, err := a.core()
	if err != nil {
		return err
	}
	defer func() {
		if s != nil {
			s.close()
		}
	}()
	if err := s.online(ctx, "external"); err != nil {
		return err
	}
	if err := scanAcceptance(ctx, a, d, s, "system"); err != nil {
		return err
	}
	if err := s.action(ctx, "refuse-system-stop", "lifecycle.stop", map[string]any{}, false); err != nil {
		return err
	}
	if err := a.inactive(); err != nil {
		return err
	}
	fmt.Println("system launcher: rescan passed, unrelated user service untouched")
	if err := command("systemctl", "stop", a.unit); err != nil {
		return err
	}
	if _, err := s.await(ctx, func(f coreFrame) bool { return f.Type == "snapshot" && !f.State.Connection.Online }); err != nil {
		return err
	}
	if err := a.inactive(); err != nil {
		return err
	}
	if err := command("systemctl", "start", a.unit); err != nil {
		return err
	}
	if err := s.online(ctx, "external"); err != nil {
		return err
	}
	fmt.Println("system outage: recovered in the same core process")
	if err := command("systemctl", "stop", a.unit); err != nil {
		return err
	}
	manual := a.cmd(nil, "syncthing", "serve", "--no-browser", "--no-restart", "--no-upgrade", "--no-port-probing")
	log, err := os.Create(filepath.Join(root, "manual.log"))
	if err != nil {
		return err
	}
	defer log.Close()
	manual.Stdout = log
	manual.Stderr = log
	if err := manual.Start(); err != nil {
		return err
	}
	defer func() {
		if manual != nil {
			manual.Process.Signal(syscall.SIGTERM)
			manual.Wait()
		}
	}()
	if err := waitAPI(ctx, d); err != nil {
		return err
	}
	if err := s.online(ctx, "external"); err != nil {
		return err
	}
	if err := scanAcceptance(ctx, a, d, s, "manual"); err != nil {
		return err
	}
	if err := a.inactive(); err != nil {
		return err
	}
	fmt.Println("manual launcher: rescan passed, unrelated user service untouched")
	manual.Process.Signal(syscall.SIGTERM)
	manual.Wait()
	manual = nil
	if _, err := s.await(ctx, func(f coreFrame) bool {
		return f.Type == "snapshot" && !f.State.Connection.Online
	}); err != nil {
		return err
	}
	if err := a.inactive(); err != nil {
		return err
	}
	manual = a.cmd(nil, "syncthing", "serve", "--no-browser", "--no-restart", "--no-upgrade", "--no-port-probing")
	manual.Stdout, manual.Stderr = log, log
	if err := manual.Start(); err != nil {
		return err
	}
	if err := s.online(ctx, "external"); err != nil {
		return err
	}
	fmt.Println("manual outage: recovered in the same core process")
	manual.Process.Signal(syscall.SIGTERM)
	manual.Wait()
	manual = nil
	if err := a.run("systemctl", "--user", "enable", "--now", "syncthing.service"); err != nil {
		return err
	}
	if err := waitAPI(ctx, d); err != nil {
		return err
	}
	// Each launcher installation gets a fresh session, as in popup acceptance.
	s.close()
	s, err = a.core()
	if err != nil {
		return err
	}
	if err := s.online(ctx, "managed"); err != nil {
		return err
	}
	if err := s.action(ctx, "managed-stop", "lifecycle.stop", map[string]any{}, true); err != nil {
		return err
	}
	if err := s.action(ctx, "managed-start", "lifecycle.start", map[string]any{}, true); err != nil {
		return err
	}
	if err := s.online(ctx, "managed"); err != nil {
		return err
	}
	fmt.Println("managed launcher: authorized stop and start passed")
	s.close()
	s = nil
	if err := a.run("systemctl", "--user", "disable", "--now", "syncthing.service"); err != nil {
		return err
	}
	standard := filepath.Join(a.home, ".local/state/syncthing")
	custom := filepath.Join(a.home, "custom-syncthing")
	if err := os.Rename(standard, custom); err != nil {
		return err
	}
	manual = a.cmd(nil, "syncthing", "serve", "--home", custom, "--no-browser", "--no-restart", "--no-upgrade", "--no-port-probing")
	manual.Stdout = log
	manual.Stderr = log
	if err := manual.Start(); err != nil {
		return err
	}
	if err := waitAPI(ctx, d); err != nil {
		return err
	}
	if output, err := a.cmd(nil, "syncshell-core", "status", "--json").CombinedOutput(); err == nil || !strings.Contains(string(output), "configuration was not found") {
		return errors.New("custom configuration discovery limitation changed")
	}
	s, err = a.core("STHOMEDIR=" + custom)
	if err != nil {
		return err
	}
	if err := s.online(ctx, "external"); err != nil {
		return err
	}
	fmt.Println("custom path: explicit environment selection works; default discovery limitation retained")
	result := map[string]any{"result": "passed", "checks": []string{"system launcher with inactive user unit", "manual launcher with inactive user unit", "real rescan through core protocol", "external stop refused", "outage recovery without core restart", "managed stop/start", "custom config limitation and environment selection"}}
	data, _ := json.MarshalIndent(result, "", "  ")
	return os.WriteFile(filepath.Join(root, "results.json"), append(data, '\n'), 0644)
}
