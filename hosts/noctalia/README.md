# Syncshell for Noctalia

Native Luau controls for Syncthing, backed by one bundled Go worker. Offline
behavioral checks cover the panel and its callbacks. Native rendering,
compositor focus and two-peer synchronization still require acceptance on a
Noctalia system.

Targets Linux x86_64 and Noctalia source revision
`8240b170dbbbf47b231170a795b24ae9ac7923f6` (`VERSION` 5.2.1), plugin API 31.
The pin does not identify a released version providing API 31. Other releases
and architectures are not advertised as tested. Opening directories and help
links needs `xdg-utils`. Install and configure Syncthing separately.

## Build and install

From the checkout, with Go, Python 3.11+ and standard GNU tools:

```sh
bash integrations/noctalia/assemble.sh
cd dist/noctalia
sha256sum --check PACKAGE-SHA256SUMS
noctalia plugins lint "$PWD"
```

The lint command is offline. Run installation and the following Noctalia
commands only on the intended Noctalia host:

```sh
set -e
package_dir="$PWD"
plugin_dir="${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins/syncshell"
test ! -e "$plugin_dir" && test ! -L "$plugin_dir"
mkdir -p -- "$(dirname -- "$plugin_dir")"
cp -a -- "$package_dir" "$plugin_dir"
noctalia msg plugins enable syncshell/syncshell
noctalia msg panel-toggle syncshell/syncshell:panel
```

For a linked development installation, use `ln -s -- "$package_dir"
"$plugin_dir"` instead of the copy. Add `syncshell/syncshell:bar` through
Noctalia's bar widget picker. Both clicks open the panel unless overridden;
middle click retains Noctalia's settings behavior. The local data directory
outranks other sources with the same plugin ID. Review an existing
installation before replacing it.

The package needs no checkout, compiler or download at installation time.
From the checkout, prepare a custom-source export without publishing:

```sh
bash integrations/noctalia/assemble.sh --export
```

This creates `dist/noctalia-export/catalog.toml` and its `syncshell/` payload.
The development repository itself is not a directly installable store source.
Store acceptance, binary policy, name availability and thumbnails remain
publication work outside this implementation.

## Behavior

The overview provides aggregate file/byte totals, service and connection
status, folder/device cards, activity, transfer rates, sharing, invitations,
scans and Web UI controls. Refresh rechecks problem folders when connected
and retries discovery when disconnected. Forget requires unlinking first;
it removes folder configuration while leaving local files intact.

Sharing review separates confirmed and unconfirmed shares. Remote-paused
folders count as confirmed only with fresh, connected device state. Stale,
offline and not-sharing-back states have distinct explanations. Search and
remote acceptance retain edits; new shares remain selected. Unavailable
sharing data cannot be submitted as an empty selection.

Selectors collapse to summaries and expand into a dedicated selection view.
They include descriptions, stable IDs, search, paging and explicit return.
Folder filters support mixed All, reset and name/activity/error sorting.
Add-folder forms offer pending sources and generated or manual IDs. Device
forms normalize IDs and reject local/known identities. Encrypted offers use
the Web UI. Settings and device creation can return to the parent draft.

The directory picker supports editable location, parent/back navigation,
large-directory pages, keyboard selection, errors, cancellation and return.
Late replies cannot overwrite a canceled picker or another directory.

More/Less shows errors across folders, affected paths, shown/total counts,
stale-error labels, copying, retries and a full Web UI route. Error and
invitation collections use bounded pages. Long notices have full-detail
views; long plain text is split into UTF-8-safe label segments for reading
and can be copied without truncation. Success notices expire; failures remain
recoverable. Activity uses valid native colors and second-tick dots while
fresh; these are text updates, not a claim of identical Omarchy animation.

## Geometry and keyboard

The approved adaptation uses a fixed 480 by 700 panel, clamped by the host.
Forms replace the body. Selection and detail views use the same panel with
an explicit return. Footers remain outside their scrollable content. Escape
retains native dismissal; closing the panel retains drafts in memory.
Unsubmitted drafts are never written to disk.

| View         | Owned keys                                               |
| ------------ | -------------------------------------------------------- |
| Overview     | r rescan, w Web UI, p service, s settings, q close       |
| Action rows  | Alt+Up/Down selects; Alt+Enter activates                 |
| Selection    | Alt+Up/Down selects; Enter in search chooses or toggles  |
| Selection    | Alt+Enter activates; Alt+Left returns                    |
| Directory    | Enter in location goes there; Alt+Enter opens selection  |
| Confirmation | Alt+Up/Down chooses; Alt+Enter activates; default Cancel |
| Nested view  | Alt+Left returns or cancels                              |

Native Tab/Shift-Tab traverses controls; Enter/Space activates the native
focused button. Printable keys and plain editing arrows remain with text
inputs. Native Enter is not globally captured. Confirmations freeze their
targets, put Cancel first and reject activation within 300 ms of opening.
Busy/result guards prevent duplicate in-flight actions. Direct action
buttons receive a new native key on dispatch so a held native activation
cannot retain focus on the replacement action.

The owned action cursor highlights buttons and repeats the chosen action
and context in the footer. It is distinct from native keyboard focus. The
pinned API has no arbitrary button-focus or ensure-visible binding. It also
does not implement automatic focused-control scrolling for plugin panels.
Input focus is available only on creation. Selection windows therefore move
with the owned cursor and recreate their scroll viewport; selection views
keep the search and return controls together. Exact native button-focus
restoration and automatic tab-to-offscreen scrolling remain host limitations,
not accepted parity exceptions. Native focus and scroll behavior need testing.

## Settings and management

Use Noctalia plugin settings for connection paths, endpoint/TLS, refresh and
probe intervals, icon style, login preference and explicit service authority.
API keys remain in Go; settings contain a credential-file path, never a key.
Refresh intervals range from 60 to 3600 seconds. Probe intervals range from
1 to 3600 seconds.

Settings shows preferred and actual service-at-login state. A settled,
authorized binding can apply the preference after confirmation. Alternatively,
keep the actual state and change the preference in native settings. Unknown,
unsupported and unsettled unit states are explained. Enabling this plugin
never enables or starts Syncthing. External instances remain observable;
start/stop controls require the core's matching-target authorization.

Web UI choices are Syncthing default, bundled Modern and Noctalia colors.
Settings shows the configured preference and actual profile, with explicit
Apply actions. Palette refresh updates only an already-selected Noctalia
profile; it cannot take over another adapter's selection. Profiles are named
`syncshell-noctalia-modern` and `syncshell-noctalia-themed`. Templates remain
in the imported Web UI bundle.

Installation help opens the [official downloads][downloads] and
[startup documentation][startup]. Missing local binaries, unavailable
connections and externally managed instances have different guidance.

## Removal and recovery

Open Settings, then **Removal and recovery**. Restore default and remove
Noctalia profiles first. If another adapter's theme is selected, explicitly
select default before cleanup. Failures remain retryable; successful cleanup
unlocks the native removal route.

The service saves a private executable and `cleanup.sh` underneath
`pluginDataDir()/syncshell-noctalia-cleanup/`. The removal view displays and
copies its exact path. Run it to retry cleanup after package deletion. It
contains connection paths and authority flags, not credentials or drafts.
Keep the connection configuration available until cleanup succeeds.

```sh
noctalia msg plugins disable syncshell/syncshell
```

For Git-source installs, use Remove in Noctalia Settings, Plugins. Local
copies and path-source installs require removing only the package directory
or link after disabling. The panel shows that exact package path.

Noctalia retains plugin settings. To clear them, remove only
`[plugin_settings."syncshell/syncshell"]` from the declarative configuration
and resolved `settings.toml` overrides. The override file is under
`$NOCTALIA_STATE_HOME/noctalia/`, otherwise `$XDG_STATE_HOME/noctalia/`,
otherwise `~/.local/state/noctalia/`. Remove this plugin's bar placements in
native bar settings. Keep other plugins' settings, Syncthing configuration
and synchronized data. After successful cleanup and removal, the private
recovery files shown in the panel may also be removed.

## Ownership

- `NoctaliaService.luau`: worker lifetime, generation fences, results and
  palette refresh; the bar receives only a compact summary.
- `NoctaliaPanel.luau`: native entry, bounded views and key routing.
- `controllers/PanelController.luau`: drafts, confirmations and settlement.
- `models/`: status, validation, action labels and owned action navigation.
- `ui/`: forms, cards, selectors, picker and host management journeys.
- `transport/`: chunk framing, incremental JSON and snapshot banks.
- `core/internal/nativebridge/`: private request inlet in the existing worker,
  short-lived forwarding, directory browsing and saved cleanup.

Protocol 2 and existing stdio adapters remain intact. Transport version 1
uses UTF-8-safe chunks up to 4 KiB, acknowledged at most every eight chunks.
Frames retain the full 8 MiB protocol bound. A private generation directory,
singleton lock, heartbeat lease and parent checks own the worker. Delivery
is distinct from settlement; uncertain actions are never replayed. Two
bounded snapshot banks and incremental decoding spread work across callbacks.
Frame ticks run only during snapshot assembly; second ticks run only for
notice expiry, recent-link feedback or fresh activity.

## Offline verification

Checks use the pinned Luau VM, native constructors, JSON conversion and prop
schema. Host state, process and panel callbacks are test doubles; this is not
a compositor or native renderer. Noctalia and `luau-analyze` are unavailable
here, so native `plugins lint` and static Luau type analysis remain unrun.
The pinned source omits the Luau Analysis library.

```sh
python3 tests/noctalia/build-runner.py "$noctalia_source" \
  /tmp/syncshell-noctalia-luau "$json_include"
/tmp/syncshell-noctalia-luau/native-luau --check \
  $(rg --files hosts/noctalia -g '*.luau')
/tmp/syncshell-noctalia-luau/native-luau tests/noctalia/run.luau \
  tests/noctalia/parity.luau tests/noctalia/transport.luau \
  tests/noctalia/service.luau
(cd core && go test -race ./... -timeout 180s && go vet ./...)
python3 tests/noctalia/package.py dist/noctalia
python3 tests/noctalia/copied-package.py dist/noctalia
```

Coverage includes actual panel callbacks, 25 ms callback limits, three
successive full 8 MiB service/reader transfers, oversize rejection, UTF-8,
generation changes,
real-child lifetimes, copied-package use and idempotent post-deletion cleanup.
An unrelated Omarchy device-sharing hint-wording assertion also fails in
unchanged `dev`; it is not altered by this port.

## Native acceptance

- Exercise every form and action with disposable peers, including empty/all
  sharing, group changes, vanished targets, encrypted offers, missing-path
  confirmation, invalid input, pending close/reopen and failure/retry.
- Inspect totals, scanning/syncing/combined states, stale errors, auth failure,
  service stopped versus unavailable, timed notices and background failures.
- Verify native Tab/editing/Enter/Space, owned action and result cursors,
  selector/filter return, picker history/pages, confirmation defaults/repeats,
  both clicks, overrides, middle click, Escape and retained drafts.
- Check long Unicode text, maximum lists, scroll reachability, footer layout,
  fonts, scale, light/dark, activity dots, all bar edges and floating placement.
- Verify one worker with two bars/monitors, output removal, reload, settings,
  disable/enable, update, copied/linked installs and removal/recovery.
- Test credentials, custom endpoint/TLS, worker crash/restart and preservation
  of another adapter's theme/files. Verify mutations and synchronized hashes.

[downloads]: https://syncthing.net/downloads/
[startup]: https://docs.syncthing.net/users/autostart.html#linux
