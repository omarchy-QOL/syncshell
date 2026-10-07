# DankMaterialShell host

This is the in-development DMS 1.6.2 adapter. It shares the native Syncshell
worker with the other adapters and uses DMS controls and plugin lifecycle.
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
`~/.config/DankMaterialShell/plugins/`. Do not copy just the manifest or link
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

| Area                       | Files                                                         |
| -------------------------- | ------------------------------------------------------------- |
| Bar and popout composition | `DankPanel.qml`, `ui/SyncthingPanelPopup.qml`                 |
| Worker and settings        | `DankService.qml`, `controllers/SettingsController.qml`       |
| Selection and drafts       | `controllers/PanelController.qml`, `models/PanelModel.js`     |
| Header and More            | `ui/PanelStatus.qml`, `ui/MoreDetails.qml`                    |
| Folder/device cards        | `ui/FolderCard.qml`, `ui/DeviceCard.qml`                      |
| Folder creation            | `ui/AddFolderForm.qml`                                        |
| Device creation/acceptance | `ui/AddRemoteDeviceForm.qml`, `ui/AcceptRemoteDeviceForm.qml` |
| Sharing forms              | `ui/FolderSharingForm.qml`, `ui/DeviceFoldersForm.qml`        |
| Selection and filters      | `ui/SyncshellDropdown.qml`, `ui/FolderViewOptions.qml`        |
| Side forms/confirmations   | `ui/SideCardMenu.qml`, `ui/CompactConfirmDialog.qml`          |
| Settings presentation      | `ui/PluginSettings.qml`                                       |

Single- and multi-select share `SyncshellDropdown.qml`; the `multiple` mode
retains checked IDs while filtering. `MonoIcon` is replaced by native
`DankSVGIcon`; action tooltips use native buttons or the bounded plain-text
`SyncshellToolTip`. Service choices share the Cancel-first confirmation.
There is no cross-shell visual facade or copied Omarchy control library.

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
