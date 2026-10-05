package waybarconfig

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

const (
	moduleStart    = "// syncshell module start"
	moduleEnd      = "// syncshell module end"
	placementStart = "// syncshell placement start"
	placementEnd   = "// syncshell placement end"
	styleStart     = "/* syncshell style start */"
	styleEnd       = "/* syncshell style end */"
)

var (
	positionPattern  = regexp.MustCompile(`"position"\s*:\s*"(top|bottom)"`)
	modulesPattern   = regexp.MustCompile(`"modules-right"\s*:\s*\[`)
	shellWordPattern = regexp.MustCompile(`^[a-zA-Z0-9_@%+=:,./-]+$`)
)

// Run edits only the explicitly supplied adapter files, without a core session.
func Run(args []string) error {
	if len(args) == 0 || (args[0] != "install" && args[0] != "remove") {
		return errors.New("expected waybar-config install or remove")
	}
	flags := flag.NewFlagSet("waybar-config", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	config := flags.String("config", "", "Waybar config path")
	style := flags.String("style", "", "Waybar style path")
	root := flags.String("root", "", "installed adapter directory")
	if err := flags.Parse(args[1:]); err != nil {
		return err
	}
	if flags.NArg() != 0 || *config == "" || *style == "" || *root == "" {
		return errors.New("waybar-config requires --config, --style, and --root")
	}
	return update(args[0], *config, *style, *root)
}

func update(action, configPath, stylePath, root string) error {
	config, configExists, err := readOptional(configPath)
	if err != nil {
		return err
	}
	style, styleExists, err := readOptional(stylePath)
	if err != nil {
		return err
	}
	// Validate all managed blocks before changing either user file.
	config, err = stripMarked(config, moduleStart, moduleEnd)
	if err != nil {
		return err
	}
	config, err = stripMarked(config, placementStart, placementEnd)
	if err != nil {
		return err
	}
	style, err = stripMarked(style, styleStart, styleEnd)
	if err != nil {
		return err
	}
	position := "top"
	if action == "install" {
		if !configExists {
			config = "{\n  \"layer\": \"top\",\n  \"position\": \"top\",\n" +
				"  \"height\": 34,\n  \"modules-left\": [\"hyprland/workspaces\"],\n" +
				"  \"modules-right\": []\n}\n"
		}
		if match := positionPattern.FindStringSubmatch(config); match != nil {
			position = match[1]
		}
		config, err = installConfig(config, root)
		if err != nil {
			return err
		}
		style = styleStart + "\n@import url(\"syncshell.css\");\n" + styleEnd + "\n" + style
	}
	if action == "install" || configExists {
		if err := atomicWrite(configPath, config); err != nil {
			return err
		}
	}
	if action == "install" || styleExists {
		if err := atomicWrite(stylePath, style); err != nil {
			return err
		}
	}
	if action == "install" {
		return atomicWrite(filepath.Join(root, "position"), position+"\n")
	}
	return nil
}

func installConfig(text, root string) (string, error) {
	opening := strings.IndexByte(text, '{')
	if opening < 0 {
		return "", errors.New("Waybar config has no object")
	}
	quickshell := "quickshell -p " + shellQuote(root)
	values := map[string]any{
		"return-type":     "json",
		"exec":            shellQuote(filepath.Join(root, "status.sh")),
		"on-click":        quickshell + " ipc call syncshell toggle",
		"on-click-right":  quickshell + " ipc call syncshell refresh",
		"on-click-middle": quickshell + " ipc call syncshell openWebUi",
		"tooltip":         true,
	}
	encoded, err := json.MarshalIndent(values, "  ", "  ")
	if err != nil {
		return "", err
	}
	block := "\n  " + moduleStart + "\n  \"custom/syncshell\": " +
		string(encoded) + ",\n  " + moduleEnd + "\n"
	text = text[:opening+1] + block + text[opening+1:]
	if match := modulesPattern.FindStringIndex(text); match != nil {
		end := match[1]
		separator := ","
		if strings.HasPrefix(strings.TrimSpace(text[end:]), "]") {
			separator = ""
		}
		placement := "\n    " + placementStart + "\n    \"custom/syncshell\"" +
			separator + "\n    " + placementEnd + "\n    "
		return text[:end] + placement + text[end:], nil
	}
	placement := "\n  " + placementStart +
		"\n  \"modules-right\": [\"custom/syncshell\"],\n  " + placementEnd + "\n"
	return text[:opening+1] + placement + text[opening+1:], nil
}

func shellQuote(value string) string {
	if shellWordPattern.MatchString(value) {
		return value
	}
	return "'" + strings.ReplaceAll(value, "'", "'\"'\"'") + "'"
}

func stripMarked(text, start, end string) (string, error) {
	pattern := regexp.MustCompile(`(?s)[ \t]*` + regexp.QuoteMeta(start) +
		`.*?` + regexp.QuoteMeta(end) + `[ \t]*\n?`)
	clean := pattern.ReplaceAllString(text, "")
	if strings.Contains(clean, start) || strings.Contains(clean, end) {
		return "", fmt.Errorf("incomplete managed block: %s", start)
	}
	return clean, nil
}

func readOptional(path string) (string, bool, error) {
	contents, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return "", false, nil
	}
	return string(contents), err == nil, err
}

func atomicWrite(path, text string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	mode := os.FileMode(0o644)
	if info, err := os.Stat(path); err == nil {
		mode = info.Mode().Perm()
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}
	file, err := os.CreateTemp(filepath.Dir(path), ".syncshell-")
	if err != nil {
		return err
	}
	defer os.Remove(file.Name())
	if _, err := io.WriteString(file, text); err != nil {
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
