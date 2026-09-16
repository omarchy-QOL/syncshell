# Arch shell adapters

Syncshell 0.1.8 supports four native Arch Linux and Hyprland adapters. Their
panels follow the Omarchy interaction hierarchy: status first, folder cards,
advanced link and add controls under **More**, then Web UI, rescan, and refresh
actions. Forget is available only for an unlinked folder and requires
confirmation. The Omarchy adapter remains unchanged.

Every live adapter owns exactly one bundled `syncshell-core` process. The Go
core owns discovery, credentials, TLS, REST, event retries, normalized state,
and mutations. Shell code owns presentation, focus, placement, and launchers.

## Supported sources

| Adapter            | Supported source                                      |
| ------------------ | ----------------------------------------------------- |
| DMS                | installer release `v1.5.3`, DMS `1.6.1` observed     |
| Illogical Impulse  | commit `42d0aae17b744a38cd05c9044c189bfc9b13869a`    |
| Caelestia shell    | commit `1d0e5a588c61f1d905eba5fe8446ec222d37f50c`    |
| Caelestia CLI      | commit `7401d9e3a371e583bc0b42dc1a139d01e278e6c1`    |
| Caelestia QShell   | commit `0fed22a2c47d9568ddf13cf61586b3f2ac4378a2`    |
| Waybar             | `0.15.0` with Quickshell `0.3.1`                     |

The acceptance environment uses the official Arch cloud image
`20260901.583572`, Hyprland `0.56.2`, Qt `6.11.2`, and Syncthing `2.1.5`.
These versions describe the tested release lane rather than broad compatibility
promises.

## DankMaterialShell

Install or update from a clean Syncshell checkout:

```bash
./install.sh --shell dms
```

The installer assembles the plugin, enables its widget, and restarts
`dms.service`. Use DMS's plugin uninstall action to remove it. DMS removes the
plugin files while leaving Syncthing configuration and synchronized data alone.

The widget has native horizontal and vertical bar forms. Its popup uses DMS
controls and shares the daemon-owned core service.

## Illogical Impulse

Install or update against the supported Illogical Impulse configuration:

```bash
./install.sh --shell ii
```

The installer clones the pinned source, applies the overlay, and keeps replaced
files under the Syncshell state directory. To remove the adapter, restore those
files and remove only `services/Syncshell.qml`,
`modules/ii/bar/SyncshellIndicator.qml`,
`modules/ii/bar/SyncshellPopup.qml`, and the `syncshell/` directory. Restart the
II shell afterward. Do not remove Syncthing configuration or folder data.

Both top and bottom bar positions are supported and persist in II's own
configuration.

## Caelestia

Install or update against the supported Caelestia shell revision:

```bash
./install.sh --shell caelestia
```

The installer clones the pinned shell, applies the overlay, and rebuilds its
compiled configuration as version `2.3.0`. Removal rebuilds and installs the
untouched supported checkout; this removes the registered status choice,
service, popout, and bundled core without touching Syncthing.

Install Caelestia's documented Material Symbols, Rubik, and CaskaydiaCove Nerd
Font dependencies. Without them, material icon names render as text.

## Waybar

Install or update the self-contained adapter:

```bash
./install.sh --shell waybar
```

The installer assembles a verified bundle, adds marked blocks to the active
`config.jsonc` or `config`, prepends one marked CSS import, installs a user
service, and reloads Waybar. It is idempotent and keeps a first-install
`*.syncshell-before` config copy.

Remove it with:

```bash
~/.local/share/syncshell/waybar/remove.sh
```

Removal deletes only managed files and marked fragments. Unrelated Waybar
configuration, Syncthing configuration, and synchronized directories remain.
The popup follows a top or bottom Waybar position recorded during installation.

Waybar left click toggles the popup, right click refreshes status, and middle
click opens the selected Web UI. One Quickshell bridge publishes the native
Waybar JSON stream, so additional outputs do not start more core processes.
