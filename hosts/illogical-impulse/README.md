# Illogical Impulse native module

The corrective implementation is complete for pre-host validation in both
Material `ii` and Waffle. The behavior and offline evidence inventory is in
[COMPLETION.md](COMPLETION.md). Native compositor/two-peer acceptance remains
pending; this is not a native-accepted release.

## Integration contract

The tested source is `end-4/dots-hyprland` at
`33f31a08caddd41422a2d97670adeeb52b4f1e7c`, with shapes at
`e31ec4cb4ebf6a46b267f5c42eabf6874916fa16`. That source pins Quickshell to
`41651d7dcd62a9400eb6f4f8a8580efe00901efb`. Offline execution here used
Quickshell 0.3.1 and Qt 6.11.2 on Linux x86_64. The installed Hyprland version
is 0.56.2; compositor integration was not exercised.

The package owns only `syncshell/` inside the explicit target shell root.
Marked import/entry blocks touch exactly four upstream files:

- `shell.qml`: one owner outside family and monitor loaders.
- `modules/ii/bar/BarContent.qml`: horizontal Material entry.
- `modules/ii/verticalBar/VerticalBarContent.qml`: vertical Material entry.
- `modules/waffle/bar/WaffleBarContent.qml`: Waffle system-area entry.

The installer checks native API hashes, required files/imports, executable
architecture, payload checksums and exact hook contexts. It accepts a checkout
or deployed tree; Git metadata is not required. Unrelated customization is
preserved. Edited owned files/hooks, partial installs and collisions stop the
operation before replacement. Upstream updates can invalidate this contract;
there is no fuzzy patching or promise of arbitrary revision support.

## Build and install

Build in this repository. Go, Python 3 and the target's native Quickshell/Qt
runtime are required. Only the Linux x86_64 artifact has been executed here;
other architectures require their own build and execution validation.

```sh
bash integrations/illogical-impulse/assemble.sh
BUNDLE="$PWD/dist/illogical-impulse"
II_ROOT="/absolute/path/to/ii"
python3 "$BUNDLE/manage.py" check --target "$II_ROOT"
```

Run the following only on the intended Illogical Impulse host. Stop its
supervisor first if it automatically restarts Quickshell, then stop this exact
configuration. Keep it stopped throughout installation or update so file
watching cannot load a mixture of versions.

```sh
quickshell kill -p "$II_ROOT/shell.qml"
python3 "$BUNDLE/manage.py" install --target "$II_ROOT" --shell-stopped
quickshell -p "$II_ROOT/shell.qml"
```

Use the same sequence for repeat installs and updates. `--shell-stopped` is
an explicit assertion by the operator; the installer never stops or restarts
the desktop. A failed update restores the previous payload and exact file
bytes. If a process crash leaves a transaction, keep the shell stopped and
recover before retrying:

```sh
python3 "$BUNDLE/manage.py" recover --target "$II_ROOT" --shell-stopped
```

Recovery refuses to overwrite edits made after the interruption. Preserve and
resolve any reported conflicting file before retrying recovery.

The adapter starts enabled. These runtime commands stop/start only its owned
Go worker and surfaces, preserving controller state within the running shell:

```sh
quickshell ipc -p "$II_ROOT/shell.qml" call syncshell disable
quickshell ipc -p "$II_ROOT/shell.qml" call syncshell enable
```

They do not start or stop Syncthing. Explicit service choices require Go to
verify the matching authorized `syncthing.service` user instance. Externally
managed instances remain visible with an explanation of unavailable control.

## Controls and settings

Left or right click the bar entry. The panel includes local identity/status,
folder and device tabs, searchable selectors, group filters and sort/reset,
context actions, invitations, More/Less details and a persistent footer.

Folder controls cover pause/resume, rescan/recheck, open/copy ID, confirmed
forget without deleting files, creation and sharing. Creation retains offered
identity, generates editable IDs, validates paths/overlap in Go and confirms
missing-directory creation. Device controls cover add/accept/dismiss,
pause/resume/remove, address/rates, and confirmed removal of selected shares.
Confirmed and unconfirmed shares remain distinct during refresh. Encrypted
folder offers open the Web UI.

Escape closes the innermost selector, confirmation or form first. Closing the
panel or changing family retains drafts and frozen confirmations; explicit
Cancel discards them. Submitted actions cannot be repeated. Shortcuts outside
text editors are `r` refresh, `w` Web UI, `p` folder pause/resume, `s` rescan
all
and `q` close. Directory browsing uses a parented, directory-capable Qt dialog.

Settings live at `$XDG_CONFIG_HOME/syncshell/illogical-impulse.json` (default
`~/.config/syncshell/illogical-impulse.json`), outside the payload. They control
monochrome icons, probe/refresh intervals, and default/Modern/host-themed Web
UI. Family and bar placement remain authoritative in the shell's own config.
Syncshell never writes that file. Invalid adapter settings are reported and
can be corrected through Settings or the named private file.

Host-themed profiles use semantic RGB colors from `Appearance` or `Looks`.
Palette changes refresh only this adapter's already selected profile; they do
not reclaim a profile selected by another adapter. Credentials, Syncthing
requests, profile ownership and desktop-bridge authorization stay in Go.
Public IPC exposes only adapter enable/disable, with no management payloads.

## Removal and profile cleanup

In Settings, choose **Restore default and remove owned profiles** and confirm
before removing the module. If the UI is unavailable, use the bundled retry
command with the intended local Syncthing configuration. It uses the same Go
profile authority and never starts/stops Syncthing:

```sh
python3 "$BUNDLE/cleanup-profile.py" --config "/absolute/path/to/config.xml"
quickshell kill -p "$II_ROOT/shell.qml"
python3 "$BUNDLE/manage.py" remove --target "$II_ROOT" --shell-stopped
quickshell -p "$II_ROOT/shell.qml"
```

Cleanup requires an available authorized local instance. If another adapter's
profile is selected, first explicitly select Syncthing's default UI and retry;
cleanup will not replace that other selection. Only this adapter's profiles
are removed. Syncthing configuration, directories, other profiles and private
Syncshell settings remain. Hook removal works even when upstream runtime
files have changed, provided the owned payload and hook blocks are intact.

## Customization map

Edit repository sources, rebuild, then install with the shell stopped. Local
edits inside the installed payload intentionally cause checksum conflicts.

Paths below are relative to `hosts/illogical-impulse/`.

| Responsibility            | Files                                                      |
| ------------------------- | ---------------------------------------------------------- |
| Lifetime and integration  | `IllogicalHost.qml`, `IllogicalService.qml`                |
| Focus and picker          | `IllogicalPanel.qml`, `ui/BodyTabFoldersAddFormPicker.qml` |
| Geometry and navigation   | `models/PanelModel.js`, `models/PanelNavigation.js`        |
| Drafts and action targets | `controllers/PanelController.qml`                          |
| Private settings          | `controllers/SettingsController.qml`                       |
| Palette refresh           | `controllers/ThemePaletteController.qml`                   |
| Views and forms           | Responsibility-named files under `ui/`                     |
| Native controls/chrome    | `ui/ii/`, `ui/waffle/`                                     |

Controllers and workflow layouts are shared within this adapter. Small native
control components retain each family's actual APIs, icons, typography,
spacing and motion. Upstream shell libraries and browser renderer sources are
not copied into the adapter implementation.

## Offline verification

Run from the repository, with `PINNED_II` pointing at the pinned source's
`dots/.config/quickshell/ii` directory:

```sh
(cd core && go test ./... && go test -race ./...)
bash tests/illogical-impulse-adapter.test.sh
bash tests/illogical-sdk.test.sh "$PINNED_II"
bash tests/illogical-native.test.sh "$PINNED_II"
bash tests/illogical-owner.test.sh "$PINNED_II"
python3 tests/illogical/test_real_core.py "$PINNED_II"
python3 tests/illogical/test_pinned_install.py "$PINNED_II"
```

The native fixture executes pinned controls offscreen with isolated settings
and desktop services excluded; it does not launch the full shell. It tests
both families through production content: fields, left/right bar gestures,
rich selectors, nested options, keyboard/Tab/outside dismissal, Cancel-first
confirmations, forms, clipboard, diagnostics, retained state and real Qt
picker acceptance/cancel. It also checks narrow/large-text menus, actual
settings IO failure/retry, profile recovery and service confirmation input.
The real-core fixture separately asserts exact backend mutations and files.

To retain native screenshots/logs and API evidence outside Git, use new output
directories for each invocation:

```sh
SYNCSHELL_NATIVE_ARTIFACTS=/tmp/syncshell-native-evidence \
  bash tests/illogical-native.test.sh "$PINNED_II"
SYNCSHELL_CORE_ARTIFACTS=/tmp/syncshell-core-evidence \
  python3 tests/illogical/test_real_core.py "$PINNED_II"
```

Software-rendered captures verify content and geometry. They cannot validate
native tint, shadows/translucency or typography when the host fonts are
absent. In this environment Material Symbols falls back to literal icon names
and Waffle shader surfaces can be transparent. Native appearance requires the
intended host; no simplified rendering fallback replaces the native types.
SDK-aware lint resolves actual native imports; dynamic token/loader metadata
and Quickshell's runtime-selected `PanelWindow` backend are informational.
The pinned upstream `WTextField.qml:15` emits a known QColor/color-group warning
on Qt 6.11.2. The fixture permits that exact upstream diagnostic and exactly
one deliberate settings write-failure warning per family, with retained-draft
assertions.
Other warnings fail the run.

Owner tests cover family changes, disable/enable, reload and teardown, checking
actual child PIDs for leaks and overlap. Fake-server tests run the real Go
worker through actions, rescan settlement and owned-profile cleanup, including
the standalone retry command. Installer tests cover repeat/update/remove,
customizations, collisions, partial failure and forced-process-exit recovery.
A disposable full pinned-tree test checks byte-exact removal of all four hooks.

Core unit/race tests and shared process/adapter fixtures passed.
The combined folder-creation/device-sharing Node run has eight passing tests
and the baseline failure described below. The existing
`tests/device-sharing.test.mjs` text-only assertion for the Omarchy hint fails:
it expects a comma phrase while the unchanged base UI uses a slash. Both that
test and its UI input are byte-identical to the base revision.

## Native acceptance still required

Use disposable two-peer Syncthing data, not personal synchronization folders.
Capture matching views in both families and verify:

- Every action, form, invitation, setting and confirmation, with resulting
  Syncthing state and synchronized file hashes.
- Keyboard editing/tab order, nested Escape, outside dismissal, Cancel-first
  focus, picker return, sidebars/action centre, lock and overview.
- Material top/bottom/left/right and Waffle top/bottom; auto-hide, app layouts,
  two outputs/removal, fractional scale, large fonts and long text.
- Adjacent forms, edge flipping/stacking, stable main anchor, More/Less growth,
  reachable footer and light/dark/translucent native appearance.
- `ii -> waffle -> ii` during drafts, confirmations and pending actions,
  preserving targets with one worker and no replay or competing focus grabs.
- Restart/reload, disable/enable, update, cleanup/removal and recovery without
  orphan workers or changes to unrelated settings, profiles or user files.
