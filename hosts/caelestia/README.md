# Caelestia native plugin

Experimental native adapter for Caelestia PR 1703 at
`4e288c54a3b039154d19fe8a2064a174eb634405`. This is a PR-only loading contract,
not a released or marketplace installation API. The matching C++ plugin and
QML shell must come from that revision. Native acceptance is pending.

The package contains the complete panel, forms, directory picker, settings,
core, Web UI profiles and cleanup action. It does not install Syncthing or
manage a service until an exact binding is explicitly authorized in settings.

## Build and install

Run from the Syncshell source checkout. Go must match `core/go.mod`; Node,
Python, Bash and standard GNU file utilities are required for preparation.

```bash
GOTOOLCHAIN=go1.23.12 bash packaging/bundled/build.sh
bash integrations/caelestia/assemble.sh "$PWD/dist/caelestia"
(cd dist/caelestia && sha256sum --check SHA256SUMS)
```

Assembly requires an empty output directory. Move a previous build aside
before regenerating it. Install one copy on the target Caelestia host:

```bash
package="$PWD/dist/caelestia"
plugins="${XDG_DATA_HOME:-$HOME/.local/share}/caelestia/plugins"
mkdir -p "$plugins"
test ! -e "$plugins/syncshell" && test ! -L "$plugins/syncshell" && \
  cp -a "$package" "$plugins/syncshell"
```

For development, replace the final `cp` with
`ln -s "$package" "$plugins/syncshell"`. Do not install both copies: the
loader rejects duplicate `syncshell/syncshell` identities. Alternatively,
`bash install.sh --shell caelestia` assembles directly into this plugin root.
It does not rebuild, restart or patch the shell.

## Build the pinned shell on the target host

Install the dependencies listed in that revision's manual-installation
section, including Caelestia CLI, its required Quickshell build, Qt 6,
libqalculate, PipeWire, aubio, libcava, lm-sensors, fonts, CMake and Ninja.
Build outside the Syncshell repository; do not mix in another shell revision.

```bash
sdk="$HOME/src/caelestia-shell-syncshell"
prefix="$HOME/.local/opt/caelestia-syncshell"
git clone https://github.com/caelestia-dots/shell.git "$sdk"
git -C "$sdk" fetch origin 4e288c54a3b039154d19fe8a2064a174eb634405
git -C "$sdk" checkout --detach 4e288c54a3b039154d19fe8a2064a174eb634405
cmake -S "$sdk" -B "$sdk/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix" \
  -DVERSION=2.2.0 \
  -DGIT_REVISION=4e288c54a3b039154d19fe8a2064a174eb634405 \
  -DINSTALL_QSCONFDIR="$prefix/share/caelestia-shell"
cmake --build "$sdk/build" -j 4
cmake --install "$sdk/build"
```

With Caelestia stopped, add `"syncshell/syncshell"` to the `enabled` array in
`$XDG_CONFIG_HOME/caelestia/plugins.json`, preserving its other keys and
entries. Add `{"id":"syncshell","enabled":true}` to `bar.entries` in
`$XDG_CONFIG_HOME/caelestia/shell.json`, preserving the existing bar entries.
When unset, `XDG_CONFIG_HOME` means `$HOME/.config`. For a clean test config,
the relevant files are:

```json
{"enabled":["syncshell/syncshell"],"settings":{}}
```

```json
{"bar":{"entries":[{"id":"syncshell","enabled":true}]}}
```

Start the pinned installation in the target Hyprland session:

```bash
QML_IMPORT_PATH="$prefix/lib/qt6/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" \
CAELESTIA_LIB_DIR="$prefix/lib/caelestia" \
  qs -p "$prefix/share/caelestia-shell"
```

Use disposable Syncthing peers for acceptance, selecting their configuration
in Syncshell settings. Do not repoint the owner's regular Syncthing instance.
The adapter also supports explicit endpoint, credential-file, pinned TLS
certificate and expected-device-ID settings. API keys never enter QML.

## Use, ownership and removal

Both bar clicks open the panel. Search supports the Omarchy fuzzy matcher;
folder filters can combine states. Tab and arrow keys navigate controls.
Outside editors: `r` rescans, `w` opens Web UI, `p` links/unlinks the folder,
`s` opens settings and `q` closes. Escape dismisses the innermost menu,
confirmation, picker, form, then panel. Closing the panel retains drafts;
Cancel discards the current form. Confirmations reopen with Cancel focused.

Each bar acquires the singleton service; popouts borrow it. The last bar
release stops the core. A stable JS ownership record retains per-screen view
state and retires the previous QML generation before its replacement starts.
Controllers are released when their last screen owner disappears. Changing JS
requires a shell restart because this loader does not reload JS.

The host's `ShellState.componentsFor(screen)` supplies the actual bar/popout
and window references. A scoped layer-shell focus binding is restored when
the panel closes. Geometry compensates for the host's center anchor and
padding so a taller side form does not move the main pane. This pin has a
left-side bar: the form opens rightward and stacks on narrow screens.

Service start/stop and autostart changes require the exact authorized user
unit/configuration binding to match the selected instance. External instances
show their state and a reason control is unavailable. Missing installations
show package-manager guidance and support recovery through Refresh.

Web UI selection is explicit. Palette changes update only the currently
selected `syncshell-caelestia-themed` profile; another adapter's selection is
left alone. Profiles use the `caelestia` ownership marker. Use Settings,
**Restore default UI and clean owned profiles**, before disabling/removing
Syncshell. If another profile is selected, explicitly apply Default first.

For direct removal without a manager hook, run the same core action before
deleting the installed package (set `config` to the selected configuration):

```bash
package="${XDG_DATA_HOME:-$HOME/.local/share}/caelestia/plugins/syncshell"
config="/absolute/path/to/syncthing/config.xml"
set -o pipefail
printf '%s\n' \
  '{"v":2,"type":"action","id":"cleanup","action":"webui.remove-profile","args":{}}' \
  | "$package/bin/syncshell-core" stream --config "$config" \
      --web-profile-authorized --web-profile-owner caelestia \
      --web-profile-bundle "$package/webui" \
  | jq -e 'select(.type == "result" and .id == "cleanup") | .ok'
```

Proceed only if that prints `true`. Disable `syncshell/syncshell`, remove its
bar entry, then remove the single plugin directory or link. Keep Syncthing's
configuration, files and other adapters' profiles. Plugin settings live in
Caelestia's `plugins.json`; removing the package does not remove that file.

## Noninteractive checks

```bash
export CAELESTIA_SDK=/absolute/path/to/the/pinned/shell
export CAELESTIA_SDK_BUILD=/tmp/syncshell-caelestia-sdk-tests
bash tests/caelestia-adapter.test.sh
go -C core test ./...
node --test tests/adapter-contract.test.mjs tests/caelestia-*.test.mjs
bash tests/native-core-architecture.test.sh
bash tests/scripts.test.sh --installation-only
bash tests/architecture.test.sh
bash tests/plugin-acceptance-lint.test.sh
```

The SDK test builds real pinned C++ modules for static checking and runs the
pinned manifest/module scanner against copied and linked payloads. An isolated
offscreen probe uses the actual entry-point loader to verify settings injection,
generation rebinding and stable JS state. It runs controller tests with the
payload's generated named imports, verifies all checksums, executes the native
launcher argument-rejection path and compares two builds. It does not launch a
shell or Syncthing. A full shell build still requires its audio dependencies;
the static SDK build is not a replacement shell distribution.

The loader warns about static JS and the imported Web UI directory name
`syncshell-modern`; that asset directory contains no QML types. Qt 6.11.2's
installed Quickshell metadata also warns about `QProcess::ExitStatus` in the
existing process handlers. Neither warning establishes runtime acceptance.

Preparation checks passed on 2026-10-07: 11 Qt behavior tests, 17 targeted Node
contracts, all Go packages, architecture/install/lint checks, both binary
rebuild checksums and the assembled-package SDK/reproducibility suite.
The full Node suite reports 27 passes and one pre-existing failure in
`tests/device-sharing.test.mjs:138`: its expected Omarchy hint text differs
from current `dev`. The same assertion fails on the untouched main checkout.
It is not a known Caelestia runtime defect.

## Remaining native acceptance

Verify on the pinned host with disposable two-peer data:

- Actual loader imports, settings injection, one core and real status/rescan.
- Copied and linked packages; native execution on x86_64 and aarch64.
- Both clicks, focus acquisition/release, arrows/Tab, nested Escape/outside
  dismissal, Cancel-first confirmation, picker return and popup reopening.
- Every mutation, rescan completion and synchronized file hashes; all forms,
  pending/encrypted offers, errors, wrong credentials, restart and recovery.
- Main/side anchoring, long text, large fonts, scaling, empty/many rows, More
  overflow, narrow-screen stacking, light/dark themes and reduced motion.
- Two monitors/bars, removal of a monitor, enable/disable, QML reload and JS
  restart. Confirm worker exit before replacement and no orphan resources.
- Owned-profile cleanup, another adapter's selected profile, authorized versus
  external service ownership, and desktop-bridge file/conflict authorization.

These runtime behaviors are implemented but unverified. The upstream loader
remains experimental. Static tests do not establish native acceptance or
marketplace support.

## Customization and refactor decisions

| Responsibility       | File or directory                                           |
| -------------------- | ----------------------------------------------------------- |
| Loader and bar       | `CaelestiaPanel.qml`, `CaelestiaBarEntry.qml`               |
| Worker ownership     | `CaelestiaService.qml`, `models/Ownership.js`               |
| Selection and drafts | `controllers/PanelController.qml`                           |
| Settings and palette | `controllers/`                                              |
| Cards and forms      | `ui/BodyTabFoldersCard.qml`, `ui/BodyTabFoldersAddForm.qml` |
| Layout and overflow  | `ui/SyncshellPanelPopup.qml`                                |
| Native package       | `integrations/caelestia/` in the source tree                |

Equivalent components keep the cross-host filenames. The accepted-device
form shares `BodyTabDevicesAddForm`; the initial values and read-only ID
differ.
Folder overview, view options and settings-menu composition stay in the
cohesive panel instead of adding forwarding wrappers. Activity, ID copy and
small information pairs are composed directly in their cards. Native
controls own visuals; shared QML and Go own transport and domain actions.
The superseded Caelestia overlay, templates and their installer route have
been removed. Other adapters and their shared dependencies remain intact.
