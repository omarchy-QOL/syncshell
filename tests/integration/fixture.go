package main

import (
	"bytes"
	"context"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type testDaemon struct {
	root, address, key, id string
	process                *exec.Cmd
	log                    *os.File
}

func fixtureConfig(data []byte, address, syncAddress, theme string) ([]byte, error) {
	values := map[string]string{
		"configuration/gui/theme":                     theme,
		"configuration/gui/address":                   address,
		"configuration/options/listenAddress":         syncAddress,
		"configuration/options/globalAnnounceEnabled": "false",
		"configuration/options/localAnnounceEnabled":  "false",
		"configuration/options/relaysEnabled":         "false",
		"configuration/options/natEnabled":            "false",
		"configuration/options/startBrowser":          "false",
		"configuration/options/urAccepted":            "-1",
	}
	decoder := xml.NewDecoder(bytes.NewReader(data))
	var buffer bytes.Buffer
	encoder := xml.NewEncoder(&buffer)
	var stack []string
	for {
		token, err := decoder.Token()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		switch value := token.(type) {
		case xml.StartElement:
			if len(stack) == 1 && value.Name.Local == "folder" {
				if err := decoder.Skip(); err != nil {
					return nil, err
				}
				continue
			}
			stack = append(stack, value.Name.Local)
			if err := encoder.EncodeToken(token); err != nil {
				return nil, err
			}
			if replacement, ok := values[strings.Join(stack, "/")]; ok {
				if err := encoder.EncodeToken(xml.CharData(replacement)); err != nil {
					return nil, err
				}
			}
			continue
		case xml.EndElement:
			stack = stack[:len(stack)-1]
		case xml.CharData:
			if _, ok := values[strings.Join(stack, "/")]; ok {
				continue
			}
		}
		if err := encoder.EncodeToken(token); err != nil {
			return nil, err
		}
	}
	if err := encoder.Flush(); err != nil {
		return nil, err
	}
	return buffer.Bytes(), nil
}

func copyTree(source, target string) error {
	return os.CopyFS(target, os.DirFS(source))
}

func (d *testDaemon) api(ctx context.Context, method, endpoint string, body any, result any) error {
	var reader io.Reader
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			return err
		}
		reader = bytes.NewReader(data)
	}
	req, err := http.NewRequestWithContext(ctx, method, "http://"+d.address+"/rest/"+endpoint, reader)
	if err != nil {
		return err
	}
	req.Header.Set("X-API-Key", d.key)
	req.Header.Set("Content-Type", "application/json")
	response, err := http.DefaultClient.Do(req)
	if err != nil {
		return errors.New("test Syncthing is unavailable")
	}
	defer response.Body.Close()
	if response.StatusCode != 200 {
		return fmt.Errorf("test Syncthing %s returned %d", endpoint, response.StatusCode)
	}
	if result != nil {
		return json.NewDecoder(response.Body).Decode(result)
	}
	_, err = io.Copy(io.Discard, response.Body)
	return err
}

func (d *testDaemon) stop() {
	if d.process != nil && d.process.Process != nil {
		d.process.Process.Signal(os.Interrupt)
		d.process.Wait()
	}
	if d.log != nil {
		d.log.Close()
	}
}

func startTestDaemon(ctx context.Context, root, assets string, port int) (*testDaemon, error) {
	d := &testDaemon{root: root, address: "127.0.0.1:" + strconv.Itoa(port)}
	if err := os.Mkdir(root, 0700); err != nil {
		return nil, err
	}
	if err := os.WriteFile(filepath.Join(root, ".syncshell-port-fixture"), []byte("disposable Syncthing integration fixture\n"), 0600); err != nil {
		return nil, err
	}
	home := filepath.Join(root, "home")
	env := []string{}
	for _, item := range os.Environ() {
		key, _, _ := strings.Cut(item, "=")
		switch key {
		case "HOME", "STHOMEDIR", "STCONFDIR", "STDATADIR", "STGUIASSETS", "XDG_STATE_HOME", "XDG_CONFIG_HOME":
			continue
		}
		env = append(env, item)
	}
	env = append(env, "HOME="+home, "XDG_STATE_HOME="+filepath.Join(home, ".local/state"), "XDG_CONFIG_HOME="+filepath.Join(home, ".config"))
	generate := exec.CommandContext(ctx, "syncthing", "generate", "--home", home, "--no-port-probing")
	generate.Env = env
	if err := generate.Run(); err != nil {
		return nil, fmt.Errorf("generate test Syncthing: %w", err)
	}
	configPath := filepath.Join(home, "config.xml")
	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, err
	}
	theme := "default"
	if assets != "" {
		theme = filepath.Base(assets)
	}
	data, err = fixtureConfig(data, d.address, "tcp://127.0.0.1:"+strconv.Itoa(port+10), theme)
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
	d.key = config.GUI.Key
	if assets != "" {
		if err := copyTree(assets, filepath.Join(root, "gui", filepath.Base(assets))); err != nil {
			return nil, err
		}
		env = append(env, "STGUIASSETS="+filepath.Join(root, "gui"))
	}
	d.log, err = os.Create(filepath.Join(root, "syncthing.log"))
	if err != nil {
		return nil, err
	}
	d.process = exec.Command("syncthing", "serve", "--home", home, "--no-browser", "--no-restart", "--no-upgrade", "--no-port-probing")
	d.process.Env = env
	d.process.Stdout = d.log
	d.process.Stderr = d.log
	if err := d.process.Start(); err != nil {
		d.stop()
		return nil, err
	}
	deadline, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	for {
		var status struct{ MyID string }
		if err := d.api(deadline, "GET", "system/status", nil, &status); err == nil {
			d.id = status.MyID
			return d, nil
		}
		select {
		case <-deadline.Done():
			d.stop()
			return nil, errors.New("test Syncthing did not start; inspect its fixture log")
		case <-time.After(100 * time.Millisecond):
		}
	}
}

func runFixture(ctx context.Context, root, assets string, port int) error {
	if err := os.Mkdir(root, 0700); err != nil {
		return err
	}
	primary, err := startTestDaemon(ctx, filepath.Join(root, "primary"), assets, port)
	if err != nil {
		return err
	}
	defer primary.stop()
	var folder map[string]any
	if err := primary.api(ctx, "GET", "config/defaults/folder", nil, &folder); err != nil {
		return err
	}
	files := filepath.Join(primary.root, "files")
	if err := os.Mkdir(files, 0700); err != nil {
		return err
	}
	folder["id"], folder["label"], folder["path"] = "port-verification", "Port verification", files
	folder["fsWatcherEnabled"], folder["rescanIntervalS"] = false, 0
	folder["devices"] = []map[string]string{{"deviceID": primary.id}}
	if err := primary.api(ctx, "PUT", "config/folders/port-verification", folder, nil); err != nil {
		return err
	}
	ready, _ := json.Marshal(map[string]string{"url": "http://" + primary.address, "runtime": primary.root})
	if err := os.WriteFile(filepath.Join(root, "ready.json"), ready, 0600); err != nil {
		return err
	}
	fmt.Println("test frontend ready at http://" + primary.address)
	<-ctx.Done()
	return nil
}
