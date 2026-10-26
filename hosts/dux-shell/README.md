# DMS (Dux Shell) host

This is the in-development adapter for DMS 2.0.0, formerly DankMaterialShell
and now Dux Shell. It shares the native Syncshell worker with the other
adapters and uses DMS plugin lifecycle, `qs.DCommon.Widgets` controls and
the 2.0 surface roles (`cardSurface`, `chipSurface`). Earlier DMS releases
are not supported.
It has not yet passed native desktop acceptance or been submitted to the
registry. Do not interpret assembly or unit tests as visual acceptance.

## Development package

From the source repository, assemble into an empty absolute directory:

```sh
bash integrations/dankmaterialshell/assemble.sh /absolute/path/to/Syncshell
```

Assembly requires Bash, Node.js and the usual GNU file utilities. The installed
plugin does not require Node.js, a Go toolchain or install-time downloads.
It includes the Linux x86_64/aarch64 workers, assets and licenses; Syncthing
must be installed separately. No bar placement or service configuration is
changed by assembly.

For a manual DMS test, copy the complete `dist/dankmaterialshell/` directory
to a new `Syncshell` directory inside DMS's plugin directory, normally
`~/.config/dms/plugins/`. Do not copy just the manifest or link
the repository root. Enable Syncshell in DMS plugin settings and add its
widget to the desired bar. Check for another `syncshell` installation and
back up its settings first; never overwrite it with this package.

Nix users can import `integrations/dankmaterialshell/home-manager.nix`
alongside DMS's Home Manager module and set `programs.syncshell-dms.enable`.
The recipe assembles the same payload and registers it through DMS's plugin
option. It does not enable DMS itself, place a bar widget, manage Syncthing's
service or overwrite plugin settings. The recipe has not been built or tested
on NixOS; no NixOS support claim is made yet.

The DMS plugin manager owns enable/disable and removal. One daemon owns the
worker regardless of bar or monitor count. Both mouse buttons open the panel.
Shortcuts outside text fields are `r` (rescan), `w` (Web UI), `p` (start/stop
the authorized service), `s` (settings) and `q` (close). Escape closes the innermost
menu, confirmation or form first.

Settings live in DMS plugin settings under the `syncshell` object, with an
explicit schema and owner. An incompatible schema or another plugin's data
is rejected without migration or overwrite. Back up another same-ID plugin
and its settings before installing this adapter; do not install both under
`syncshell`.

Lifecycle control is off until explicitly authorized in settings. The worker
must verify that the selected Syncthing instance matches that exact systemd
user unit before allowing control. Other instances remain monitorable and
manageable through the Syncthing API, without granting service authority.

## Customization map

Paths below are relative to `hosts/dankmaterialshell/`. Equivalent QML host
responsibilities use the same filenames; native APIs are not interchangeable.

| Area                       | Files                                                                |
| -------------------------- | -------------------------------------------------------------------- |
| Bar and popout composition | `DankPanel.qml`, `ui/SyncshellPanelPopup.qml`                        |
| Worker and settings        | `DankService.qml`, `controllers/SettingsController.qml`              |
| Selection and drafts       | `controllers/PanelController.qml`, `models/PanelModel.js`            |
| Header and More            | `ui/Header.qml`, `ui/BodyMore.qml`                                   |
| Footer                     | `ui/FooterActions.qml`, `ui/FooterShortcutHint.qml`                  |
| Folder/device cards        | `ui/BodyTabFoldersCard.qml`, `ui/BodyTabDevicesCard.qml`             |
| Folder creation            | `ui/BodyTabFoldersAddForm.qml`                                       |
| Device creation/acceptance | `ui/BodyTabDevicesAddForm.qml`, `ui/BodyTabDevicesAcceptForm.qml`    |
| Sharing forms              | `ui/BodyTabFoldersShareForm.qml`, `ui/BodyTabDevicesFoldersForm.qml` |
| Selection and filters      | `ui/SharedWidgetDropdown.qml`, `ui/BodyTabFoldersViewOptions.qml`    |
| Side forms/confirmations   | `ui/BodyFormSideCard.qml`, `ui/SharedDialogConfirm.qml`              |
| Settings presentation      | `ui/SettingsPage.qml`, gear in `ui/FooterActions.qml`                |

Single- and multi-select share `SharedWidgetDropdown.qml`; the `multiple` mode
retains checked IDs while filtering. Omarchy files without a DMS twin: DMS
plugin settings replace `SettingsMenu` (`SettingsPage.qml`), the DMS plugin
manager owns removal (`SettingsSelfRemovalDialog`), and no host dialog needs
`SharedDialogChoice`. The panel follows Omarchy's three parts: `Header`, a
rule, the `Body*` area, and `FooterActions`, which starts with the second
rule. Control sizes come from `ui/UiConstants.js`; the compact buttons keep
their own wrappers because `DButton` and `DIconButton` start at 32 and 40 px.

DMS paints one popout rectangle at the requested size, so side forms open on
their own content-sized layer surface, attached to the popout at the row
that opened them, as in Omarchy. The popout registers it as a transient
surface and releases its keyboard while a form is open; the form takes the
keyboard with a brief exclusive request, because an exclusive layer receives
all pointer input on Hyprland. A masked full-screen catcher then dismisses
outside clicks. Confirmations dim the panel and centre over it instead.

## Release gates

The registry will reference this repository's generated
`dist/dankmaterialshell/` directory on its default branch. Publishing requires
an approved release, reproducible package, clean DMS screenshot and actual
install/update/removal testing. Initial platform claims are limited to the
platforms tested by the maintainer; a bundled architecture is not proof of
native execution on it.

Native acceptance is intentionally deferred to the maintainer. In particular,
verify geometry at all bar edges, More overflow, adjacent forms, nested menus,
keyboard focus, picker return, light/dark themes and multiple bars/monitors.

Repeat the non-desktop checks from the source checkout with:

```sh
go -C core test -race ./...
bash tests/dankmaterialshell-adapter.test.sh
```

These cover core outcomes against mock APIs, selection/drafts, authorization,
import boundaries and reproducible packaging. They do not run DMS, prove
real two-peer synchronization or validate a compositor/NixOS installation.

## Web UI profiles and removal

The default Web UI is left alone on first startup. Selecting Modern or DMS
theme installs a checksummed, adapter-owned profile for the verified local
Syncthing configuration. DMS palette changes update the selected DMS profile;
the imported Web UI templates remain unchanged. Explicit remote endpoints
without a local configuration do not receive filesystem profile authority.

Before removal, use **Prepare plugin removal** in Syncshell settings and
confirm restoration of the default Web UI. Cleanup removes only the marked
`syncshell-dms-modern` and `syncshell-dms-themed` directories from Syncthing's
GUI asset directory. It leaves configuration, synchronized files and other
adapters' profiles intact. Remove the plugin through DMS afterward.

DMS has no guaranteed hook for direct directory deletion. If the plugin was
already removed, select Syncthing's default Web UI first, then remove only
those two profile directories after checking their `.syncshell-profile.json`
owner is `dms`. Alternatively, re-enable this adapter and use its cleanup
action. Do not remove the enclosing GUI asset directory.
