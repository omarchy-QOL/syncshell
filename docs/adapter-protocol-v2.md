# Syncshell adapter protocol v2

Protocol v2 is the current native-core wire contract. One host adapter owns one
child, one session, one event cursor, and one serialized mutation queue.

## Transport

- UTF-8 JSON Lines travel over the child's standard input and output.
- Each line is one JSON object and is at most 8,388,608 bytes including its
  newline.
- Standard output contains protocol lines only.
- Standard error contains bounded, sanitized diagnostics only.
- The API key never appears in arguments, JSONL, errors, logs, fixtures,
  settings, or screenshots.
- The host terminates the child when its service is destroyed. Closing standard
  input requests a graceful end.
- Protocol major `2` is required. There is no version negotiation, patch
  format, second output format, daemon, socket, or client brokerage.

## Core messages

The first accepted output is `hello`:

```json
{"v":2,"type":"hello","build":{"version":"0.1.8"}}
```

State is always a complete snapshot. Revisions increase only when public state
changes, and a host replaces state only with a higher revision:

```json
{"v":2,"type":"snapshot","revision":1,"state":{}}
```

The `state` value serializes the session's public snapshot directly. It
contains host-neutral connection, identity, device, folder, pending-offer,
activity, Web UI, lifecycle, and executable facts. It
never contains Omarchy labels, layout, settings paths, icon style, Web UI
theme preference, package-manager state, or other presentation policy.

The complete state object contains these sections:

- `connection`: endpoint, health, authorization, online, and freshness
- `identity`: authenticated device ID and Syncthing version
- `devices`: bounded configured devices and connection state
- `folders`: bounded configuration, status, sharing, and current errors
- `pendingFolders`: bounded current offers and encryption flags
- `pendingDevices`: bounded unknown incoming device requests
- `nearbyDevices`: bounded unconfigured local-discovery results
- `activity`: bounded active files and the session-owned rotating current file
- `webUi`: openable URL, selected theme, and GUI-assets path
- `installation`: host-neutral executable presence and path
- `counts`: normalized folder, device, connection, problem, and syncing totals
- `truncation`: explicit counts for collection and folder-error entries omitted
  by safety bounds
- `lifecycle`: exact binding, observation, classification, and control facts

Every collection and remote string is bounded so the complete snapshot remains
within the transport line limit. The limits cover up to 128 folders, 256
devices, and 64 sharing relationships per folder. Any omitted entries are
reported through `truncation` so a host can direct the user to the Web UI. A
fresh snapshot replaces the prior state; no section is a patch or independently
revisioned cache.

Every accepted request has a non-empty caller-generated string `id` and exactly
one result:

```json
{"v":2,"type":"refresh","id":"7"}
{"v":2,"type":"configure","id":"8","config":{}}
{"v":2,"type":"action","id":"9","action":"folder.rescan","args":{"folderId":"documents"}}
{"v":2,"type":"result","id":"9","ok":true,"data":{"state":"completed","targetFolderIds":["documents"],"runningFolderIds":[]}}
```

A failed result has a stable machine code and sanitized text:

```json
{"v":2,"type":"result","id":"9","ok":false,"error":{"code":"folder_missing","message":"folder is no longer configured"}}
```

When an action refresh changes public state, the core writes that complete
snapshot before the correlated result. An action with no public state change
does not emit a duplicate snapshot. Result frames do not carry snapshot
revisions; request IDs provide correlation and snapshot frames own revision
ordering.

The one `configure` request may update `probeIntervalSeconds`,
`refreshIntervalSeconds`, and `desiredServiceState`. They are validated and
applied in memory. Lifecycle probes are lightweight and independent from the
low-frequency authoritative refresh. Configuration cannot carry credentials,
settings paths, style values, or arbitrary host objects.

The domain action names are:

- `folder.pause`
- `folder.resume`
- `folder.recheck-errors`
- `folder.rescan`
- `folder.rescan-all`
- `folder.forget`
- `folder.add-existing`
- `folder.set-sharing`
- `folder.suggest-id`
- `device.add`
- `device.remove`
- `device.dismiss-pending`
- `device.remove-folder-shares`
- `lifecycle.start`
- `lifecycle.stop`
- `lifecycle.enable`
- `lifecycle.disable`
- `webui.set-theme`
- `webui.open` (available only when the Omarchy desktop bridge is enabled)

Unsupported names fail; they do not fall back or alias another action.

Action arguments are exact:

- `folder.pause`, `folder.resume`, `folder.rescan`, and `folder.forget` take
  `folderId`.
- `folder.recheck-errors`, `folder.rescan-all`, `folder.suggest-id`, and
  lifecycle actions take an empty object. Rechecking errors rescans only active
  folders with a currently reported problem before publishing fresh state. A
  rescan-all action requires at least one linked folder. It uses Syncthing's
  concurrent all-folder request only when every configured folder is active.
  If any folder is paused, it sends bounded concurrent requests only for the
  active folder IDs. Rescan-all is rejected when the configured folder count
  exceeds the bounded snapshot, because completion could not be observed for
  every target.
- `folder.add-existing` takes `folderId`, `path`, optional `label`, bounded
  `deviceIds`, and optional `pendingDeviceId`.
- `folder.set-sharing` takes `folderId` and bounded `deviceIds`. It replaces
  that folder's remote-device membership while retaining the local device.
- `device.add` takes `deviceId` and an optional `deviceName`.
- `device.remove` takes `deviceId` and removes it from the local configuration.
- `device.dismiss-pending` takes `deviceId`.
- `device.remove-folder-shares` takes `deviceId` and bounded `folderIds`. It
  removes only the specified existing relationships.
- `webui.set-theme` takes `theme`.
- `webui.open` takes no arguments. It launches the selected GUI with a private
  desktop grant; the result and snapshots contain no grant.

Successful folder-ID suggestion and add results return the resulting
`folderId` in `data`. Irrelevant fields are rejected rather than ignored.

Both rescan actions return typed `data`. `state` is `completed` after a normal
HTTP completion, or `running` only when a timed-out request was confirmed by
authoritative folder status. `targetFolderIds` is the sorted active target set.
`runningFolderIds` is the sorted subset of timed-out targets still scanning
after the action refresh. An unconfirmed timeout remains an error. Hosts track
only those reported running IDs and announce completion after all of them leave
scanning.

## Termination and protocol failure

A host may send a correlated `shutdown` request. Requests are processed
serially, so shutdown runs after any action already being handled. The core
emits the shutdown result, emits `end`, cancels its event loop, and exits:

```json
{"v":2,"type":"shutdown","id":"10"}
{"v":2,"type":"result","id":"10","ok":true}
{"v":2,"type":"end","reason":"shutdown"}
```

An unrecoverable framing or version error emits one `fatal` line when output is
still safe, then exits nonzero:

```json
{"v":2,"type":"fatal","code":"protocol_version","message":"protocol major 2 required"}
```

Malformed, recent duplicate, oversized, or post-shutdown requests never invoke
an action. Completed request IDs are remembered in a bounded rolling window;
the window never imposes a process lifetime. A crash is process state owned by
the host adapter; it is not represented as Syncthing offline.
