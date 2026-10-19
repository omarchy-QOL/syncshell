# Waybar host

A native, read-only Waybar status module backed by the shared Go session.
The bar shows only the [Syncshell icon](fonts/README.md). Hover shows folder
and connected-device counts, tracked files/bytes and current status.

```text
Syncshell · XPS

Folders                                   44
Devices                     1 of 2 connected
Tracked                  145k files · 22 GiB

Status                      Syncing 3 folders
             File syncing... Upload demo.mp4
```

Labels stay left-aligned and values share a right edge. Concurrent statuses
rotate every three seconds; the icon retains the highest-priority state.
Current file activity appears on its own line beneath Status, without folder
names or full paths. The dots advance every 500 ms; filename selection reuses
the core's activity rotation. Long names are shortened at grapheme boundaries.
Activity remains visible while other simultaneous statuses rotate, and clears
when the core clears it. These are activity indications, not percentages.

Errors, stale data, paused folders/devices, disconnected peers and invitations
have explicit states. Stale/unavailable counts are not shown as live values.
An incomplete snapshot is marked; `+` denotes incomplete collection totals.
There are no buttons, click actions, folder lists or standalone popup.

## Build and run

From the repository root:

```sh
cd core
go build -o /tmp/syncshell-waybar ./cmd/syncshell-waybar
/tmp/syncshell-waybar status
```

By default, the core discovers an unambiguous local Syncthing configuration.
An optional `$XDG_CONFIG_HOME/syncshell/waybar.json` (normally
`~/.config/syncshell/waybar.json`) selects a target explicitly:

```json
{"syncthing_config": "/absolute/path/to/syncthing/config.xml"}
```

Alternatively, select an endpoint and a private API-key file:

```json
{
  "endpoint": "https://example:8384",
  "api_key_file": "/absolute/path/to/private-key-file",
  "tls_certificate": "/absolute/path/to/https-cert.pem",
  "expected_device_id": "EXPECTED-SYNCTHING-DEVICE-ID"
}
```

The certificate and expected identity are optional protections supported by
the shared client. The credential file must be a private regular file, e.g.
mode `0600`. Keep credentials out of Waybar configuration and command lines.
Paths inside this JSON file must be absolute. Use
`status --config /absolute/path/waybar.json` to override the configuration
location. Do not combine `syncthing_config` with endpoint-specific fields.
After a successful connection, restart the module to change its target or
credentials. Missing configuration retries with bounded backoff; connection
and event recovery belong to the core.

## Waybar configuration

The [module fragment](config.jsonc) targets Waybar 0.15.0. Include its module
definition in your Waybar configuration and add `custom/syncshell` to your
chosen module list. Set `exec` to the absolute built binary path if it is not
on Waybar's PATH, retaining the leading `exec`. Paths containing spaces need
shell quoting. Each configured bar instance owns its own monitoring process.

Make `SyncshellIcons.ttf` discoverable through Fontconfig before activation;
`fc-match 'Syncshell Icons'` should select that font. The three private-use
glyphs are not supplied by ordinary text fonts. An ASCII fallback can replace
the static icon format with `ST`, without changing tooltip behavior.

The icon inherits foreground color. Users may map the module's semantic CSS
classes to their own palette: `healthy`, `error`, `syncing`, `scanning`,
`paused`, `disconnected`, `stale`, and the other keys in `format-icons`.
Classes include simultaneous conditions, so an error rule should take
precedence over activity styling. No fixed palette or global CSS is shipped.

`text` and `tooltip` carry the same plain-text body. The trusted
`tooltip-format` wraps `{text}` in a scoped monospace span for alignment;
Waybar's `escape: true` protects dynamic names and filenames. Keep that
escaping enabled and do not insert dynamic markup. Tooltip colors and other
styling continue to come from the user's GTK/Waybar theme.

## Validation and remaining work

```sh
cd core
go test -race ./internal/waybar ./cmd/syncshell-waybar ./internal/session
go vet ./...
go test ./...
```

Font rebuild/render checks are described in [the font guide](fonts/README.md).
The executable tests use a fake authenticated Syncthing API, never the user's
daemon. No desktop setup is performed by these build or test commands.

Live Waybar hover refresh, custom themes/fonts and bar orientations still need
target-host validation. Installation and distribution are deferred; this is
not a published installable release. The root installer does not offer Waybar;
use the build and configuration instructions above for development testing.
