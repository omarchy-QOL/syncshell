# Bundled Web UI

The frontend source and complete browser suite live in the standalone
[syncshell-webui](https://github.com/syncshell/syncshell-webui) repository.
This repository carries its compiled release in `webui/`, so ordinary plugin
installation needs neither Node nor a download.

Import a release during plugin development:

```sh
go -C core run ./cmd/import-webui --version 0.1.2 --sha256 EXPECTED_SHA256
```

For a local release, additionally pass `--archive /absolute/release.tar.gz`.
The importer validates the exact archive checksum, paths, asset inventory and
integration format before atomically replacing `webui/` on Linux. It uses the
existing Go module. `webui/import.json` records the
version, source commit and archive checksum. Never edit imported assets here;
change the Web repository and import a new release.

`hosts/omarchy/scripts/syncthing-theme.sh` installs Modern or Omarchy profiles.
The Web release owns the CSS template and browser refresh helper. The plugin
owns palette discovery, settings, launcher behavior and the Go desktop bridge.

Run the focused consumer checks with:

```sh
npm ci --prefix tests/webui
cd tests/webui && npx playwright install chromium && cd ../..
bash scripts/test-webui-integration.sh
```

These check checksum refusal, asset installation, real API access, Omarchy
palette refresh and the production desktop bridge. The full frontend suite
and historical fixtures run only in the Web repository. Tests are development
tools and are absent from the imported Web release.

## Automated updates

`update-webui.yml` accepts `webui-release` dispatches or manual version and
checksum inputs. It imports and tests the release, then opens an update PR
against `dev`. It does not merge or publish the plugin.

Set `SYNCSHELL_APP_ID` as a repository variable and
`SYNCSHELL_APP_PRIVATE_KEY` as a secret in both repositories. The App needs
Contents and Pull requests write permissions on `omarchy-QOL/syncshell`.
The receiving workflow must be on this repository's default branch before
GitHub can deliver dispatches. See the Web repository's `RELEASES.md` for the
release and activation procedure.
