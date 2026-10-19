// Package webprofile installs owned profiles from a verified Web UI bundle.
package webprofile

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

const markerName = ".syncshell-profile.json"

var ownerPattern = regexp.MustCompile(`^[a-z][a-z0-9-]{0,31}$`)
var colorPattern = regexp.MustCompile(`^#[0-9a-fA-F]{6}$`)

type Policy struct {
	Authorized bool
	Owner      string
	Bundle     string
}

type marker struct {
	Owner  string `json:"owner"`
	Digest string `json:"digest"`
}

func (p Policy) Validate() error {
	if !p.Authorized {
		return errors.New("Web UI profile installation is not authorized")
	}
	if !ownerPattern.MatchString(p.Owner) || !filepath.IsAbs(p.Bundle) {
		return errors.New("Web UI profile authority is incomplete")
	}
	return nil
}

func (p Policy) Name(style string) (string, error) {
	if err := p.Validate(); err != nil {
		return "", err
	}
	if style != "modern" && style != "themed" {
		return "", errors.New("unsupported Web UI profile")
	}
	return "syncshell-" + p.Owner + "-" + style, nil
}

// plainPath rejects redirected ancestors before replacing or removing a profile.
func plainPath(path string, missing bool) error {
	if !filepath.IsAbs(path) || filepath.Clean(path) == string(filepath.Separator) {
		return errors.New("profile path must be an absolute non-root directory")
	}
	for current := filepath.Clean(path); current != string(filepath.Separator); current = filepath.Dir(current) {
		info, err := os.Lstat(current)
		if missing && errors.Is(err, fs.ErrNotExist) {
			continue
		}
		if err != nil {
			return errors.New("profile path is unavailable")
		}
		if info.Mode()&os.ModeSymlink != 0 || !info.IsDir() {
			return errors.New("profile path contains a link or non-directory")
		}
	}
	return nil
}

func (p Policy) checkOwned(path string) error {
	if err := plainPath(path, false); err != nil {
		return err
	}
	info, err := os.Lstat(filepath.Join(path, markerName))
	if err != nil || !info.Mode().IsRegular() || info.Size() > 4096 {
		return errors.New("refusing to change an unowned Web UI profile")
	}
	data, err := os.ReadFile(filepath.Join(path, markerName))
	var value marker
	if err != nil || json.Unmarshal(data, &value) != nil || value.Owner != p.Owner {
		return errors.New("Web UI profile belongs to another adapter")
	}
	return nil
}

func readRegular(root, relative string) ([]byte, error) {
	if !filepath.IsLocal(relative) || filepath.Clean(relative) != relative {
		return nil, errors.New("invalid bundle path")
	}
	path := filepath.Join(root, relative)
	if err := plainPath(filepath.Dir(path), false); err != nil {
		return nil, err
	}
	info, err := os.Lstat(path)
	if err != nil || !info.Mode().IsRegular() || info.Size() > 8<<20 {
		return nil, errors.New("bundle file is unavailable or invalid")
	}
	return os.ReadFile(path)
}

func (p Policy) verifiedBundle() (map[string][]byte, error) {
	// Plugin managers may link the package root into their installation tree.
	bundle, err := filepath.EvalSymlinks(p.Bundle)
	if err != nil {
		return nil, errors.New("Web UI bundle is unavailable")
	}
	manifest, err := readRegular(bundle, "SHA256SUMS")
	if err != nil {
		return nil, err
	}
	files := make(map[string][]byte)
	scanner := bufio.NewScanner(strings.NewReader(string(manifest)))
	total := 0
	for scanner.Scan() {
		line := scanner.Text()
		if len(line) < 67 || line[64:66] != "  " {
			return nil, errors.New("invalid Web UI checksum manifest")
		}
		name := line[66:]
		if _, exists := files[name]; exists {
			return nil, errors.New("duplicate Web UI checksum entry")
		}
		content, err := readRegular(bundle, name)
		if err != nil {
			return nil, err
		}
		sum := sha256.Sum256(content)
		if hex.EncodeToString(sum[:]) != line[:64] {
			return nil, errors.New("Web UI bundle checksum mismatch")
		}
		total += len(content)
		if total > 16<<20 || len(files) >= 2048 {
			return nil, errors.New("Web UI bundle exceeds profile limits")
		}
		files[name] = content
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	if len(files["gui/syncshell-modern/index.html"]) == 0 {
		return nil, errors.New("Web UI bundle has no entrypoint")
	}
	return files, nil
}

// Prepare returns a theme name only after the complete profile is in place.
func (p Policy) Prepare(assets, style string, palette map[string]string) (string, error) {
	name, err := p.Name(style)
	if err != nil {
		return "", err
	}
	if err := plainPath(assets, true); err != nil {
		return "", err
	}
	files, err := p.verifiedBundle()
	if err != nil {
		return "", err
	}
	var css string
	if style == "themed" {
		css, err = renderPalette(string(files["integration/omarchy-theme.css.in"]), palette)
		if err != nil {
			return "", err
		}
	}
	if err := os.MkdirAll(assets, 0700); err != nil {
		return "", err
	}
	target := filepath.Join(assets, name)
	digest := profileDigest(files, style, css)
	if _, err := os.Lstat(target); err == nil {
		if err := p.checkOwned(target); err != nil {
			return "", err
		}
		data, err := os.ReadFile(filepath.Join(target, markerName))
		var existing marker
		if err == nil && json.Unmarshal(data, &existing) == nil && existing.Digest == digest {
			return name, nil
		}
	} else if !errors.Is(err, fs.ErrNotExist) {
		return "", err
	}
	stage, err := os.MkdirTemp(assets, ".syncshell-"+p.Owner+"-")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(stage)
	for path, content := range files {
		const prefix = "gui/syncshell-modern/"
		if !strings.HasPrefix(path, prefix) {
			continue
		}
		output := filepath.Join(stage, strings.TrimPrefix(path, prefix))
		if err := os.MkdirAll(filepath.Dir(output), 0700); err != nil {
			return "", err
		}
		if err := os.WriteFile(output, content, 0600); err != nil {
			return "", err
		}
	}
	if style == "themed" {
		generation := fmt.Sprintf("%x", sha256.Sum256([]byte(css)))
		wrapper := "/* omarchy-generation: " + generation + " */\n@import \"syncshell-" + palette["mode"] + ".css\";\n"
		wrapper += "@import \"omarchy_syncthing_theme.css?v=" + generation + "\";\n"
		index := strings.ReplaceAll(string(files["gui/syncshell-modern/index.html"]),
			`href="assets/css/theme.css"`, `href="assets/css/theme.css?v=`+generation+`"`)
		index = strings.Replace(index, "</head>", `<script defer src="assets/js/omarchy_theme_refresh.js" data-theme-version="`+generation+`"></script></head>`, 1)
		outputs := map[string][]byte{
			"assets/css/theme.css": []byte(wrapper), "assets/css/omarchy_syncthing_theme.css": []byte(css),
			"assets/js/omarchy_theme_refresh.js": files["integration/omarchy-theme-refresh.js"],
			"index.html":                         []byte(index), "theme-version.txt": []byte(generation + "\n"),
		}
		for path, content := range outputs {
			if len(content) == 0 {
				return "", errors.New("profile template is missing")
			}
			if err := os.MkdirAll(filepath.Dir(filepath.Join(stage, path)), 0700); err != nil {
				return "", err
			}
			if err := os.WriteFile(filepath.Join(stage, path), content, 0600); err != nil {
				return "", err
			}
		}
	}
	ownership, _ := json.Marshal(marker{Owner: p.Owner, Digest: digest})
	if err := os.WriteFile(filepath.Join(stage, markerName), ownership, 0600); err != nil {
		return "", err
	}
	previous := stage + "-previous"
	if _, err := os.Lstat(target); err == nil {
		if err := os.Rename(target, previous); err != nil {
			return "", err
		}
	}
	if err := os.Rename(stage, target); err != nil {
		_ = os.Rename(previous, target)
		return "", err
	}
	if err := os.RemoveAll(previous); err != nil {
		return "", err
	}
	return name, nil
}

func profileDigest(files map[string][]byte, style, css string) string {
	keys := make([]string, 0, len(files))
	for key := range files {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	hash := sha256.New()
	fmt.Fprintf(hash, "profile-1\x00%s\x00%s\x00", style, css)
	for _, key := range keys {
		fmt.Fprintf(hash, "%s\x00%d\x00", key, len(files[key]))
		hash.Write(files[key])
	}
	return hex.EncodeToString(hash.Sum(nil))
}

// Remove touches only fixed profile names carrying this adapter's owner marker.
func (p Policy) Remove(assets string) error {
	if err := p.Validate(); err != nil {
		return err
	}
	if err := plainPath(assets, true); err != nil {
		return err
	}
	var owned []string
	for _, style := range []string{"modern", "themed"} {
		name, _ := p.Name(style)
		target := filepath.Join(assets, name)
		if _, err := os.Lstat(target); errors.Is(err, fs.ErrNotExist) {
			continue
		}
		if err := p.checkOwned(target); err != nil {
			return err
		}
		owned = append(owned, target)
	}
	for _, target := range owned {
		if err := os.RemoveAll(target); err != nil {
			return err
		}
	}
	return nil
}

func renderPalette(template string, palette map[string]string) (string, error) {
	if template == "" || (palette["mode"] != "dark" && palette["mode"] != "light") {
		return "", errors.New("profile palette or template is missing")
	}
	for _, key := range []string{"background", "surface", "surfaceVariant", "foreground",
		"muted", "accent", "success", "warning", "danger", "border", "info"} {
		if !colorPattern.MatchString(palette[key]) {
			return "", errors.New("profile palette contains an invalid semantic color")
		}
	}
	// Template names are imported Web UI internals, not host theme settings.
	tokens := map[string]string{
		"palette": "portable", "mode": palette["mode"], "background": palette["background"],
		"surface": palette["surface"], "surface_dark": palette["surfaceVariant"],
		"foreground": palette["foreground"], "foreground_light": palette["foreground"],
		"foreground_dark": palette["muted"], "accent": palette["accent"],
		"muted": palette["border"], "selection": palette["surfaceVariant"],
		"red": palette["danger"], "yellow": palette["warning"], "bright_yellow": palette["warning"],
		"green": palette["success"], "cyan": palette["info"], "blue": palette["accent"],
		"magenta": palette["accent"], "orange": palette["warning"],
	}
	for key, value := range tokens {
		template = strings.ReplaceAll(template, "{{"+key+"}}", value)
	}
	if strings.Contains(template, "{{") {
		return "", errors.New("profile template has unresolved tokens")
	}
	return template, nil
}
