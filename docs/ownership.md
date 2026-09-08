# Syncshell ownership

This is the ownership map for the 0.1.8 architecture. Omarchy presentation
and settings live in the host adapter around the native core.

| Path                         | Sole responsibility                         |
| ---------------------------- | ------------------------------------------- |
| `core/`                      | Go native core                              |
| `core/internal/syncthing/`   | discovery, secrets, transport, wire data    |
| `core/internal/session/`     | normalized state, events, retries, actions  |
| `core/internal/systemduser/` | one trusted user lifecycle binding          |
| `core/internal/desktop/`  | local browser grant and bounded user file actions |
| `core/internal/protocol/`    | bounded JSONL for session public types      |
| `shared/CoreProcess.qml`     | child process and serialization boundary    |
| `hosts/omarchy/`             | Omarchy facade, settings, UI, and platform  |
| `hosts/standalone/`          | maintained contract harness                 |
| `packaging/bundled/`         | reproducible x86_64 artifact tooling        |
| `webui/modern/`              | portable bundled browser frontend          |

The root `Panel.qml`, `Service.qml`, and `manifest.json` remain regular-file
Omarchy entry points. They are boundaries, not additional owners.

## State and policy

- API health is authoritative for the selected instance.
- One session owns discovery, connection, hydration, events, retry, public
  state, and serialized mutations.
- Lifecycle controls require a host-authorized exact unit and a verified match
  to the selected target. Unit presence or activity is not authority.
- `hosts/omarchy/` alone owns
  `$XDG_CONFIG_HOME/omarchy/ilyazar.syncthing/settings.toml` and its four
  fields.
- The core receives only host-neutral operational values. It never receives
  the Omarchy settings path, icon style, or Web UI theme preference.
- `shared/CoreProcess.qml` knows framing and process state, not Syncthing or
  systemd semantics.
- Protocol code serializes session public types directly. No repository,
  service, mapper, DTO, or view-model chain may merely rename values.

## Runtime and updates

Retained Omarchy presentation and settings files live in `hosts/omarchy/`.
Replaced REST, credential, event, state, folder, and lifecycle QML code was
deleted from its original paths.
There is no mixed runtime, fallback, alias, or feature flag.

Users restart the shell after updating to load the current panel, service,
and bundled core together. The interval before restart is unsupported. Old
helpers or runtime compatibility paths are not retained for that interval;
released implementations remain available in Git history.

The bundled browser frontend is served by Syncthing. Omarchy owns preparing
its runtime profiles and generating the Omarchy palette; the modern source
contains no Omarchy commands or QML dependencies. An Omarchy-hosted core also
provides an ephemeral loopback endpoint for explicit local file actions. It
uses the selected client, validates local process/configuration identity and
requires the exact GUI origin and private tab grant. The endpoint exposes no
general command execution, file inventory or credential API. It closes with
the core and does not add a daemon or system service.

The future host directories are README-only in 0.1.8 and make no support claim.

## SyncThingy discovery

When native configuration discovery finds nothing, the core checks
SyncThingy's two documented config locations under
`~/.var/app/com.github.zocker_160.SyncThingy/`: `config/syncthing/` and
`.local/state/syncthing/`. It reuses the config parser, configured API address
and TLS certificate validation. Multiple Flatpak configs require explicit
selection through the core's `--config` option.

The host checks `flatpak info` only when no native binary is available, so an
installed but stopped SyncThingy is not offered a duplicate package install.
Start SyncThingy through its own launcher. Discovering it does not authorize
the default native user service, and desktop file actions keep their existing
container restrictions. No Flatpak permissions are changed.

Configuration locations and launcher behavior are documented in
[SyncThingy's source](https://github.com/zocker-160/SyncThingy/tree/e74c695d011f9e6174d7dab5fd6c9d5ab653e7dc).
