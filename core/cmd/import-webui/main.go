//go:build linux

// Import one verified Web UI release into the plugin checkout.
package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"golang.org/x/sys/unix"
)

var versionPattern = regexp.MustCompile(`^\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?$`)
var digestPattern = regexp.MustCompile(`^[a-f0-9]{64}$`)
var sourcePattern = regexp.MustCompile(`^[a-f0-9]{40}$`)
var repoPattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$`)

func main() {
	root := flag.String("root", "..", "plugin checkout (relative to core when using go -C core)")
	version := flag.String("version", "", "exact Web UI version without v")
	digest := flag.String("sha256", "", "expected archive SHA-256")
	archive := flag.String("archive", "", "local archive instead of a GitHub download")
	repo := flag.String("repo", "syncshell/syncshell-webui", "Web UI release repository")
	flag.Parse()
	log.SetFlags(0)
	if !versionPattern.MatchString(*version) || !digestPattern.MatchString(*digest) || !repoPattern.MatchString(*repo) {
		log.Fatal("provide a release version, lowercase SHA-256 and owner/repository")
	}
	data, err := readArchive(*archive, *repo, *version)
	if err == nil {
		err = importRelease(*root, *version, *digest, data)
	}
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Imported syncshell-webui %s (%s)\n", *version, *digest)
}

func readArchive(file, repo, version string) ([]byte, error) {
	if file != "" {
		return os.ReadFile(file)
	}
	url := fmt.Sprintf("https://github.com/%s/releases/download/v%s/syncshell-webui-v%s.tar.gz", repo, version, version)
	client := http.Client{Timeout: 60 * time.Second}
	response, err := client.Get(url)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("release download: %s", response.Status)
	}
	return io.ReadAll(response.Body)
}

func importRelease(root, version, expected string, data []byte) error {
	if !versionPattern.MatchString(version) || !digestPattern.MatchString(expected) {
		return errors.New("invalid release version or SHA-256")
	}
	if digest(data) != expected {
		return errors.New("archive checksum mismatch; existing bundle retained")
	}
	staging, err := os.MkdirTemp(root, ".webui-import-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(staging)
	name := "syncshell-webui-v" + version
	files, err := extractArchive(staging, name, data)
	if err != nil {
		return err
	}
	bundle := filepath.Join(staging, name)
	source, err := verifyBundle(bundle, version, files)
	if err != nil {
		return err
	}
	if err := recordImport(bundle, version, source, expected); err != nil {
		return err
	}
	return replaceBundle(bundle, filepath.Join(root, "webui"))
}

func digest(data []byte) string { return fmt.Sprintf("%x", sha256.Sum256(data)) }

func extractArchive(staging, name string, data []byte) (map[string]string, error) {
	compressed, err := gzip.NewReader(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	defer compressed.Close()
	archive := tar.NewReader(compressed)
	files, seen := map[string]string{}, map[string]bool{}
	for {
		header, err := archive.Next()
		if err == io.EOF {
			return files, nil
		}
		if err != nil {
			return nil, err
		}
		path := strings.TrimSuffix(header.Name, "/")
		if !fs.ValidPath(path) || strings.ContainsAny(path, "\\\r\n") || seen[path] ||
			(path != name && !strings.HasPrefix(path, name+"/")) {
			return nil, fmt.Errorf("invalid archive path: %q", header.Name)
		}
		seen[path] = true
		target := filepath.Join(staging, filepath.FromSlash(path))
		if header.Typeflag == tar.TypeDir {
			if err := os.MkdirAll(target, 0755); err != nil {
				return nil, err
			}
			continue
		}
		if header.Typeflag != tar.TypeReg && header.Typeflag != tar.TypeRegA {
			return nil, fmt.Errorf("nonregular archive asset: %q", path)
		}
		content, err := io.ReadAll(archive)
		if err != nil {
			return nil, err
		}
		if err := os.MkdirAll(filepath.Dir(target), 0755); err != nil {
			return nil, err
		}
		if err := os.WriteFile(target, content, 0644); err != nil {
			return nil, err
		}
		files[strings.TrimPrefix(path, name+"/")] = digest(content)
	}
}

func verifyBundle(bundle, version string, files map[string]string) (string, error) {
	data, err := os.ReadFile(filepath.Join(bundle, "manifest.json"))
	if err != nil {
		return "", err
	}
	var manifest struct {
		Name, Version, Source string
		IntegrationFormat     int
	}
	if json.Unmarshal(data, &manifest) != nil || manifest.Name != "syncshell-webui" ||
		manifest.Version != version || manifest.IntegrationFormat != 1 || !sourcePattern.MatchString(manifest.Source) {
		return "", errors.New("unsupported or mismatched release manifest")
	}
	for _, file := range []string{"gui/syncshell-modern/index.html", "integration/omarchy-theme.css.in", "integration/omarchy-theme-refresh.js", "install.sh"} {
		if _, ok := files[file]; !ok {
			return "", fmt.Errorf("release is missing %s", file)
		}
	}
	data, err = os.ReadFile(filepath.Join(bundle, "SHA256SUMS"))
	if err != nil {
		return "", err
	}
	delete(files, "SHA256SUMS")
	if files["import.json"] != "" {
		return "", errors.New("release contains plugin-owned import metadata")
	}
	for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
		checksum, path, ok := strings.Cut(line, "  ")
		if !ok || !digestPattern.MatchString(checksum) || files[path] != checksum {
			return "", fmt.Errorf("invalid asset checksum: %q", line)
		}
		delete(files, path)
	}
	if len(files) != 0 {
		return "", errors.New("incomplete release checksum inventory")
	}
	return manifest.Source, nil
}

func recordImport(bundle, version, source, checksum string) error {
	record, _ := json.MarshalIndent(map[string]string{"version": version, "source": source, "sha256": checksum}, "", "  ")
	record = append(record, '\n')
	if err := os.WriteFile(filepath.Join(bundle, "import.json"), record, 0644); err != nil {
		return err
	}
	sums, err := os.OpenFile(filepath.Join(bundle, "SHA256SUMS"), os.O_APPEND|os.O_WRONLY, 0)
	if err != nil {
		return err
	}
	_, err = fmt.Fprintf(sums, "%s  import.json\n", digest(record))
	return errors.Join(err, sums.Close())
}

func replaceBundle(bundle, target string) error {
	info, err := os.Lstat(target)
	if errors.Is(err, fs.ErrNotExist) {
		return os.Rename(bundle, target)
	}
	if err != nil {
		return err
	}
	if !info.IsDir() {
		return errors.New("webui must be a regular directory")
	}
	// The old bundle stays active if the atomic exchange fails.
	return unix.Renameat2(unix.AT_FDCWD, bundle, unix.AT_FDCWD, target, unix.RENAME_EXCHANGE)
}
