# Status colors

Read this before choosing a color for a Syncshell state in any adapter:
Omarchy, Dux Shell (DMS), Caelestia, Illogical Impulse, Noctalia, Waybar,
the TUI or the Web UI.

The Omarchy plugin defines what each state means. Every other adapter keeps
those meanings and only takes the color values from its own shell theme.
Do not reinterpret a state through a shell's own conventions; for example,
syncing stays a warning color even where the shell uses its accent for
progress.

## Semantic roles

Omarchy resolves yellow, green and cyan from the active theme with
`omarchy-theme-color --all` (`hosts/omarchy/models/ThemePaletteModel.js`
holds the fallbacks). Red is the bar's `urgent` color and muted is Omarchy's
`Color.muted`.

| Role    | Omarchy color      | Meaning                                   |
| ------- | ------------------ | ----------------------------------------- |
| success | theme green        | healthy, up to date, connected, completed |
| warning | theme yellow       | in motion or stopped: syncing, paused     |
| error   | `Color.urgent` red | failed, destructive, removing             |
| info    | theme cyan         | synchronization activity                  |
| muted   | `Color.muted`      | unknown, disconnected, secondary text     |

## States

The Omarchy source of each rule is named in the last column, relative to
`hosts/omarchy/`.

| Surface             | State or element                       | Role                      | Omarchy source                             |
| ------------------- | -------------------------------------- | ------------------------- | ------------------------------------------ |
| Folder card, list   | SYNCED, LINKED                         | success                   | `OmarchyPanel.qml` `folderStateColor`      |
| Folder card, list   | SYNCING, SCANNING, SCAN+SYNC, UNLINKED | warning                   | `OmarchyPanel.qml` `folderStateColor`      |
| Folder card, list   | ERROR                                  | error                     | `OmarchyPanel.qml` `folderStateColor`      |
| Folder card, list   | UNKNOWN                                | muted                     | `OmarchyPanel.qml` `folderStateColor`      |
| Device card, list   | CONNECTED                              | success                   | `ui/BodyTabDevices.qml` `deviceStateColor` |
| Device card, list   | PAUSED                                 | warning                   | `ui/BodyTabDevices.qml` `deviceStateColor` |
| Device card, list   | DISCONNECTED                           | muted                     | `ui/BodyTabDevices.qml` `deviceStateColor` |
| Activity line       | syncing                                | info                      | `ui/BodyTabFoldersCardActivity.qml`        |
| Activity line       | removing                               | error                     | `ui/BodyTabFoldersCardActivity.qml`        |
| Activity line       | upload                                 | success                   | `ui/BodyTabFoldersCardActivity.qml`        |
| More, status word   | clean / errors / unavailable           | success / error / muted   | `ui/BodyMore.qml`                          |
| More, installation  | existing / incomplete / missing        | success / error / warning | `ui/BodyMore.qml`                          |
| Header notice       | completed action                       | success                   | `ui/Header.qml`                            |
| Hints               | unconfirmed shares, no nearby device   | warning                   | sharing and device forms                   |
| Destructive actions | remove, forget, confirm Yes            | error                     | `ui/SharedDialogConfirm.qml`               |

## Adapter tokens

Each adapter maps the roles to its shell's theme tokens. Record a token here
when an adapter adopts it; mark a role "open" until the adapter decides.

### Dux Shell (DMS)

`hosts/dux-shell/models/PanelModel.js` (`folderStateRole`,
`deviceStateRole`, `activityRole`) returns the `Theme` property names below.
DMS defines `success`, `warning` and `info` as fixed Material colors under
the wallpaper theme; custom and stock themes can override them.

| Role    | Token                    |
| ------- | ------------------------ |
| success | `Theme.success`          |
| warning | `Theme.warning`          |
| error   | `Theme.error`            |
| info    | `Theme.info`             |
| muted   | `Theme.onSurfaceVariant` |

### Caelestia

Caelestia's palette has `m3success` and `m3error` but no warning or info
role, and its terminal colors follow the wallpaper rather than ANSI hues.

| Role    | Token                                |
| ------- | ------------------------------------ |
| success | `Colours.palette.m3success`          |
| warning | open                                 |
| error   | `Colours.palette.m3error`            |
| info    | open                                 |
| muted   | `Colours.palette.m3onSurfaceVariant` |

### Illogical Impulse

`Appearance.m3colors` offers `m3success` and the `colError` family; its
`term*` colors follow the wallpaper.

| Role    | Token                           |
| ------- | ------------------------------- |
| success | `Appearance.m3colors.m3success` |
| warning | open                            |
| error   | `Appearance.colors.colError`    |
| info    | open                            |
| muted   | `Appearance.colors.colSubtext`  |

### Noctalia

The pinned v5 API exposes no dedicated success, warning or information roles.
`hosts/noctalia/controllers/ThemePaletteController.luau` owns the mapping used
by the native cards/header and the Web UI palette:

| Role    | Native token          |
| ------- | --------------------- |
| success | `tertiary`            |
| warning | `secondary`           |
| error   | `error`               |
| info    | `primary`             |
| muted   | `on_surface_variant`  |

Folder and device state meanings follow Omarchy through `PanelModel.luau`.
For example, scanning and paused states use warning, while connected devices
use success only when not paused and the snapshot is fresh. State text remains
visible alongside color.

This mapping preserves semantic separation but does not guarantee Omarchy's
success-green, warning-yellow or information-cyan hues. Native theme roles
may use other hues. Treat that as an unresolved visual difference, pending
native light/dark comparison and a supported semantic-palette solution.
Do not report it as verified color parity.

### Waybar, TUI and Web UI

- Waybar: states are CSS classes; the user's stylesheet colors them.
- TUI: ANSI success, warning and danger roles and cyan/teal for information
  (`syncshell-tui`).
- Web UI: the adapter's themed profile receives `success`, `warning`,
  `danger` and `info` from the host palette.
