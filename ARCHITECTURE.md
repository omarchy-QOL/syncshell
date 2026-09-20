# Syncshell core architecture implementation specification

## Status and scope

This implementation goal was completed and verified on 2026-09-20. The
current working tree and maintained contract documents are the source of truth
for existing behavior.

The review covers the complete runtime path in the current
`feat-device-addition` working tree:

```text
shell UI
  -> host or shared QML service
  -> CoreProcess and JSONL
  -> Session state and use cases
  -> Syncthing client
  -> Syncthing REST and Event APIs
```

`request` and `jsonRequest` are private client helpers. They are not services
or architectural boundaries. Syncthing is the external system.

The implementation goal is to keep these boundaries and make their contracts
smaller and more explicit. It must not move REST policy into QML, duplicate
Syncthing state in another daemon, or add interfaces around the concrete
client.

The implementation was authorized as one goal and completed without changing
the runtime boundaries described here.

## Code evidence map

The paths below are used throughout the specification:

| Alias | Current source |
|-------|----------------|
| `P` | `core/internal/protocol/protocol.go` |
| `S` | `core/internal/session/` |
| `C` | `core/internal/syncthing/` |
| `CP` | `shared/CoreProcess.qml` |
| `A` | `shared/AdapterService.qml` |
| `O` | `hosts/omarchy/OmarchyService.qml` |
| `U` | Syncthing v2.1.3 source at tag `v2.1.3` |

The following decisions were checked against current symbols and consumers:

| Decision | Current evidence | Required action |
|----------|------------------|-----------------|
| Keep the child process | QML cannot import the Go package; `CP` owns one child and restart state | No boundary change |
| Keep `Session` policy | `S/actions.go` and `S/device_actions.go` re-read and validate authoritative state | No boundary change |
| Keep the semantic client | `C/client.go` and `C/mutations.go` own paths, verbs, auth, TLS, bounds, and wire types | No boundary change |
| Keep request IDs | `CP._pending` correlates interleaved snapshots and results | Retain IDs and duplicate detection |
| Keep snapshot revisions | `CP.acceptSnapshot` rejects old or repeated generations | Retain snapshot revisions |
| Keep frame `v` | Go validates every request and `CP.handleLine` validates every output | Retain one major on every frame; the cleaned contract is v2 |
| Keep complete snapshots | Every host replaces state atomically; no host implements patch merging | Retain complete snapshot frames |
| Keep strict decoding | `P.decodeStrict` rejects unknown request fields | Retain strict request decoding |
| Remove hello capabilities | `CP.acceptHello` never reads them | Remove the field and fixture data |
| Remove Go build version | No QML or Go runtime consumer reads it | Keep only the product version in build metadata |
| Remove host identity | Only an exact Omarchy comparison enables the desktop bridge | Replace startup identity with explicit desktop authority |
| Remove action capabilities | Only `A.hasCapability` reads the static list; core and QML ship together | Remove the snapshot list and the QML gate together |
| Remove public mutation data | No QML reads `state.mutation` | Replace its publication side effect before removal |
| Remove result revisions | Current callbacks accept but do not use them | Remove the result field and callback argument together |
| Fix lifecycle repetition | `S/waitForLifecycle` invokes `Apply` inside its poll loop | Apply once, then observe |
| Fix rescan semantics | `C.Client.Rescan` maps both completed and running scans to `nil` | Return a typed disposition and typed action data |
| Keep manual cloning for now | `S.clonePublished` is required by `Current` and public callbacks | Add complete alias-isolation coverage |
| Keep the activity lock | It is small, correct, and documents ownership; removing it has no measured value | Revisit only with an activity-owner refactor |
| Keep complete event refreshes for now | `S.requiresHydration` deliberately favors authoritative reads | Measure before adding targeted caches |
| Keep the action argument union for now | It is strictly decoded and exhaustively shape-tested | Split only when another action makes it materially harder to maintain |
| Keep current client file layout | `C/mutations.go` is 166 lines and remains navigable | Rename or split only with related client work |

Two corrections to the earlier architecture review follow from this evidence:

1. `Snapshot.mutation` is unused as data, but `publishMutation` currently
   sends the refreshed snapshot before the action result. Removing the field
   without replacing that ordering would leave QML temporarily stale.
2. Published generations cannot simply stop being cloned. `Current` returns
   slices, maps, and pointers to callers. Internal immutability alone would not
   prevent a caller from mutating shared backing storage.

## Required invariants

Every implementation phase must preserve these behaviors:

1. One live adapter owns one core child, one session, and one Event API cursor.
2. QML sends domain actions and never receives credentials or constructs REST
   requests.
3. The session serializes mutations with `actionMu` and refreshes authoritative
   state after a successful or ambiguous write.
4. A changed action snapshot is written before that action's result frame.
5. Snapshot revisions remain monotonic and duplicate generations are not sent.
6. Every result ID matches one pending QML callback exactly once.
7. Public errors remain bounded, stable, and free of credentials.
8. Folder and device mutations preserve Syncthing-owned fields.
9. A rescan success never means that an unconfirmed timed-out request was
   accepted.
10. A completion notice never appears while one of that action's reported
    running targets is still scanning.

## Work package 1: make rescan behavior explicit

### Current behavior

`C.Client.Rescan` posts to `/rest/db/scan` through the ordinary client, whose
timeout is 15 seconds. A normal HTTP 200 means Syncthing finished the scan.
After a timeout, `rescanStarted` reads folder status and returns success only
when at least one applicable state begins with `scan`.

The returned `error` has only two observable values:

- `nil` after HTTP 200, when the requested scan is complete;
- `nil` after a timeout and status check, when a scan is still running.

That loss of meaning caused two QML implementations:

- `O.settlePendingRescan` completes immediately when the result arrives and no
  target is scanning;
- `A.settleRescan` requires `_rescanObserved` first, so a fast scan can leave
  the action busy forever.

`S.rescanAll` has a separate correctness problem. It checks that at least one
folder is active and then posts to `/rest/db/scan` without a folder ID.
Syncthing v2.1.3 `ScanFolders` invokes `ScanFolder` for every configured
folder. `checkFolderRunningRLocked` returns `ErrFolderPaused` for a paused
folder, so the REST handler reports an error even when active folders were
scanned.

The upstream behavior is established by:

- `U/lib/api/api.go`, `postDBScan`;
- `U/lib/model/model.go`, `ScanFolders` and `ScanFolderSubdirs`;
- `U/lib/model/folder.go`, `folder.Scan`;
- `U/lib/model/model.go`, `checkFolderRunningRLocked`.

### Candidate designs

| Candidate | Benefit | Cost or failure | Decision |
|-----------|---------|-----------------|----------|
| Wait without the 15-second limit | Simple completion meaning | Blocks the serialized action path for an unbounded scan and weakens transport bounds | Reject |
| Return success as soon as POST starts | Short action | The endpoint is synchronous and provides no accepted-operation response | Reject |
| Fix only `_rescanObserved` | Smallest patch | Keeps two trackers and keeps completed/running ambiguity | Reject |
| Store a long-lived operation in `Session` | One central tracker and restart-visible state | Adds public operation state, timers, and reconciliation for one UI concern | Reject for now |
| Typed Go result plus one shared QML tracker | Preserves bounded calls, exact targets, and host-independent completion | Adds a small result type and shared QML component | Choose |

### Result contract

Both `folder.rescan` and `folder.rescan-all` return this action data:

```json
{
  "state": "completed",
  "targetFolderIds": ["documents"],
  "runningFolderIds": []
}
```

or:

```json
{
  "state": "running",
  "targetFolderIds": ["documents", "photos"],
  "runningFolderIds": ["photos"]
}
```

`state` accepts exactly `completed` or `running`.
`targetFolderIds` is the sorted set captured before the scan starts.
`runningFolderIds` is a sorted subset that was still scanning after the
post-request refresh. It is empty for `completed`.

The core result remains successful in both cases. `running` means the timeout
was confirmed by authoritative folder status; an unconfirmed timeout remains
an error.

### Go changes

In `C/client.go`:

1. Add an internal `RescanDisposition` with `completed` and `running` values.
2. Change `Client.Rescan` to return `(RescanDisposition, error)`.
3. Return `completed` only after HTTP 200.
4. Return `running` only after `ErrorTimeout` and a successful scanning-state
   check.
5. Preserve the original classified error for every other case.

In `S/types.go`:

1. Add a typed `RescanResult` with `State`, `TargetFolderIDs`, and
   `RunningFolderIDs` JSON fields.
2. Use that type as `ActionResult.Data` for the two explicit rescan actions.

In `S/actions.go`:

1. `rescanFolder` retains its current online, existence, path, and pause
   checks.
2. Capture its one folder ID as the target before calling the client.
3. After the client returns, run one complete `Refresh`.
4. If the disposition is `completed`, return `state: completed` even if an
   unrelated automatic scan has since started.
5. If the disposition is `running`, inspect the refreshed state for the one
   target. Return `running` only if its state still begins with `scan`;
   otherwise return `completed`.

For `rescanAll`:

1. Read configured folders and sort all active IDs.
2. Reject zero configured folders with `folder_missing`.
3. Reject an empty active set with `folder_paused`.
4. Preserve the active IDs as `targetFolderIds` for the result.
5. If every configured folder is active, keep the global endpoint. Syncthing
   performs those folder scans concurrently.
6. If any folder is paused, post one folder-specific request for each active
   ID. Use a small bounded worker group so ordinary configurations remain
   concurrent without creating an unbounded number of HTTP requests.
7. Let the bounded workers attempt every active ID and collect dispositions
   and errors by folder ID. After every worker exits, refresh once and return
   the first error in sorted folder order.
8. After success, refresh once. Only timed-out targets whose refreshed state
   still begins with `scan` belong in `runningFolderIds`.

Use a named package constant of eight workers. This is Syncshell resource
policy rather than a Syncthing limit. It avoids a goroutine and connection for
every entry in an unusually large configuration. Do not add a new dependency
for the worker group.

`folder.recheck-errors` may discard the disposition because its contract is a
best-effort error recheck followed by fresh state. It must still propagate an
unconfirmed timeout or other request error.

### QML changes

Add `shared/RescanTracker.qml` as a nonvisual `QtObject`. It owns only:

- the sorted `runningFolderIds` from a successful action result;
- `acceptResult(data, scanningFolderIds)`;
- `reconcile(scanningFolderIds)`;
- `reset()`;
- one `completed` signal and one invalid-result return path.

The services remain responsible for busy state, action names, target labels,
notices, and notifications. Each service supplies an array of currently
scanning folder IDs, so the shared tracker does not depend on either host's
folder model shape.

`acceptResult` behaves as follows:

1. Validate `state`, target IDs, and running IDs.
2. Emit completion immediately for `completed`.
3. Store the reported running IDs for `running`.
4. Reconcile immediately against the current snapshot. The protocol ordering
   guarantee makes that snapshot at least as new as the action refresh.
5. Emit completion when none of the reported running IDs remains scanning.

In `A`, remove `_rescanResultReady`, `_rescanObserved`,
`rescanTargetsScanning`, and `settleRescan`. In `O`, remove
`pendingRescanResultReady`, `rescanTargetsScanning`, and
`settlePendingRescan`. Both services instantiate the shared tracker and retain
their existing host-specific notice text and core-loss errors.

### Rescan acceptance tests

Add or update tests for all of these cases:

1. Client HTTP 200 returns `completed`.
2. Confirmed timeout returns `running`.
3. Timeout followed by idle status returns the original timeout error.
4. One-folder fast scan completes without observing a scanning snapshot.
5. One-folder long scan stays busy until its reported ID leaves scanning.
6. All active folders use the global endpoint and preserve sorted targets.
7. A mix of active and paused folders sends requests only for active IDs.
8. Mixed completed and running targets report only running IDs.
9. One failure in the mixed path refreshes state and returns an error without
   a completion notice.
10. Core loss and API loss clear tracker and service busy state.
11. The Omarchy and shared-adapter paths use the same tracker semantics.

The existing Syncthing client, session action, adapter service, core-loss, and
plugin acceptance tests are the starting fixtures. Extend them rather than
adding a second mock protocol.

## Work package 2: remove unused wire state without losing ordering

### Current publication dependency

`S.Act` currently publishes a busy `Mutation`, runs the action, and publishes a
terminal `Mutation`. `P.handleAction` passes a callback that writes both
snapshots and advances `lastRevision`.

No QML code reads `state.mutation`; each service already marks itself busy
before calling `core.action`. The terminal mutation still has a useful side
effect: it writes the state produced by `Refresh` before the result. That side
effect must be replaced explicitly.

### Exact protocol changes

In `S/types.go`, remove:

- `Mutation`;
- `Snapshot.HostID`;
- `Snapshot.Mutation`;
- `Snapshot.Capabilities`;
- `ActionResult.Revision`.

In `S/session.go` and `S/normalize.go`:

- stop placing host ID, mutation, and action capabilities in snapshots;
- remove their clone branches;
- remove `Config.HostID` and `Session.hostID` if no internal owner remains.

The desktop bridge uses the explicit `--desktop-authorized` startup option.
Other adapters supply no host identity or desktop-authority argument.

In `S/actions.go`:

1. Keep `actionMu` and all action dispatch and validation.
2. Remove `requestID` and the publication callback from `Session.Act`.
3. Remove `publishMutation` and `finishMutation`.
4. Return the domain result directly.

In `P/protocol.go`:

1. Add one private helper that writes `Session.Current()` only when its
   revision exceeds `lastRevision`.
2. Call it after every `Session.Act` and before writing that action's result.
3. Use the same helper for configure and refresh to keep one ordering rule.
4. Remove `Result.Revision` and every assignment from `ActionResult.Revision`.
5. Remove `Hello.Capabilities`, `Build.GoVersion`, and `Build.Protocol`.
6. Keep `Build.Version`, frame `v`, snapshot revision, and request IDs.
7. Publish the cleaned contract as v2 without a v1 compatibility path.

The action order after this change is:

```text
QML marks its request busy
  -> protocol validates action
  -> session serializes and executes action
  -> session refreshes current state when required
  -> protocol writes a newer complete snapshot, if any
  -> protocol writes the correlated result
```

An event-loop update may occur while a synchronous action is running. Reading
`Session.Current()` at the end publishes the newest generation available at
that point. A queued event update at the same or an older revision is then
discarded by the existing `lastRevision` check.

### QML changes

In `CP`:

- change result callbacks from `(ok, revision, data, error)` to
  `(ok, data, error)`;
- change `resultReceived` accordingly;
- stop reading `message.revision` from result frames;
- retain the `revision` property for snapshot frames and pending-failure
  recovery.

Update the callback signatures in `A`, `O`, `StandaloneService.qml`, and QML
tests. No callback currently branches on the result revision.

In `A`:

- remove the `capabilities` projection and `hasCapability`;
- remove the capability rejection from `runAction`.

Omarchy already sends its fixed actions without a capability gate. Its
`webui.open` call retains the current fallback to the normal URL when the
desktop action fails.

### Protocol acceptance tests

The updated protocol tests must prove:

1. Hello contains the product version without capabilities, Go version, or a
   duplicate protocol-major field.
2. Snapshots contain no host ID, mutation, or static action list.
3. Results contain ID, success, optional data, and optional error, without a
   revision.
4. A successful action that changes state emits the changed snapshot before
   its result.
5. A failed action that refreshes after an ambiguous write also emits changed
   state before its result.
6. An action with no state change emits no duplicate snapshot.
7. A concurrent event generation is not followed by an older action snapshot.
8. QML still rejects unknown or duplicate result IDs.

Do not remove snapshot revisions or request IDs while simplifying result
frames.

## Work package 3: apply lifecycle actions once

### Current behavior

`S.lifecycleAction` refreshes and verifies authority, then calls
`waitForLifecycle`. That function refreshes in a loop and invokes
`s.lifecycle.Apply` on every unsuccessful iteration.

The repeated calls are normally idempotent, but they launch unnecessary
`systemctl` processes and make failure timing depend on the observation loop.

### Exact change

Keep the initial authoritative refresh and all current authorization checks.
Then:

1. Return success immediately if the desired lifecycle state is already
   reached.
2. Call `s.lifecycle.Apply` exactly once.
3. Return `lifecycle_failed` immediately if that call fails.
4. Poll with `Refresh` every 200 milliseconds until the desired state appears,
   the ten-second deadline expires, or the context is canceled.
5. Never call `Apply` from the observation loop.

Extend `S/lifecycle_test.go` with a command invocation counter. Assert one
mutating invocation for delayed success, timeout, and command failure, and
zero invocations when the requested state is already present or authority is
rejected.

## Work package 4: harden existing state ownership

### Keep cloning and test every reference field

`S.Current`, publication, lifecycle updates, activity updates, and freshness
updates all return `clonePublished` results. The function must remain while a
caller can receive slices, maps, or pointers.

Add one table-driven `TestCurrentReturnsIsolatedState` in
`S/session_test.go`. Build a populated snapshot, obtain a copy, mutate every
reference-bearing field in that copy, and assert that a second `Current()` is
unchanged. Cover:

- `Connection.Error`;
- folder devices and folder status errors;
- pending-folder maps and nested offer maps;
- pending devices;
- nearby devices and nested addresses;
- activity files and current activity.

The mutation and capability cases disappear in work package 2. Whenever a new
reference field is added to `Snapshot`, this isolation test must fail until
`clonePublished` handles it.

Do not replace the clone with JSON marshal/unmarshal. That would add avoidable
allocation and turn an internal ownership rule into serialization behavior.

### Keep the activity lock

Current production access to activity records occurs on the event-loop
goroutine, but `activityMu` is four simple lock operations around mutable map
and index state. There is no measured contention or complexity problem.
Retain it. If activity becomes a dedicated collaborator later, move the lock
with its fields and methods in one change.

### Verify request-ID eviction

The current `P.validateRequest` already calls
`delete(ids.seen, ids.order[0])` once when the 4,096-entry history is full.
The duplicate call described by the earlier review was not present in the
implementation baseline, so no production change was required.

The existing protocol test accepts more than 4,096 unique IDs and then
verifies that the oldest ID can be reused while a still-retained ID is
rejected.

## Deliberately deferred changes

### Targeted Event API reconciliation

One complete refresh currently performs `11 + 2F` sequential Syncthing REST
requests, where `F` is the number of folders within the published limit. The
count comes directly from `S.Refresh`, `hydrate`, `loadAuthenticated`, and
`loadFolders`.

`S.requiresHydration` already coalesces every event batch into at most one
complete refresh. There is no current trace showing that those refreshes cause
user-visible latency or harmful API load. Keep the authoritative behavior for
this implementation goal.

If measurement later justifies targeted reconciliation, make it a separate
goal with these entry conditions:

1. Record request counts and refresh duration during a sustained real scan.
2. Identify which event categories dominate the complete refreshes.
3. Re-check the event payloads against the supported Syncthing source tag.
4. Prototype targeted authoritative reads without patching snapshots directly
   from event payloads.
5. Replay the same event sequences through targeted and complete paths and
   assert equal public snapshots.

Startup, reconnect, event-ID gaps, unknown events, `ConfigSaved`, targeted-read
failure, and the periodic timer must retain complete-refresh fallback. Cover
pending additions and removals, discovery expiry, connection changes, folder
errors, a fast scan, and a scan longer than 15 seconds.

Do not add 100 or more lines of category caches and fallback logic before the
measurement and parity gates exist.

### Session collaborators

`Session` is broad, but its current fields have identified jobs and the source
is already split by concern. Do not introduce `snapshotBuilder`, `stateStore`,
or `activityTracker` merely to shorten the struct.

Reconsider one concrete collaborator only when a change would otherwise add a
second owner or make lock ordering unclear. Keep it in the session package and
use concrete types unless a second implementation exists.

### Action-specific argument types

The current `ActionArguments` union is verbose, but `decodeStrict`,
`validateActionArguments`, and the exhaustive shape test reject irrelevant
fields. Keep it during the work above.

Reconsider per-action types when adding another argument-bearing action or
when one current action needs a nested shape. At that point, decode the raw
`args` object after routing by action name and preserve strict unknown-field
rejection.

### Client file organization

`C/mutations.go` includes reads and writes, but it is currently 166 lines and
the methods are easy to locate. Do not split it solely for naming purity.
Rename or divide it by resource only while making related client changes, with
no behavior or interface layer added.

### Cross-shell visual models

`A` serves DMS, Illogical Impulse, Caelestia, and Waybar. Omarchy keeps a
richer facade and host-specific settings. Their folder and device projections
have different presentation needs. Keep the shared `CoreProcess`, service,
device workflow, and proposed rescan tracker. Defer further visual-model
deduplication until the device interaction has stable live-host evidence.

### Local-device connected count

`S.normalizeDevices` marks the local device connected and
`normalizedCounts` counts it. This is the separately tracked connection-count
defect. It is outside this architecture implementation goal and must not be
silently bundled into the cleanup above.

## Implementation order

Implement and review the work in this order:

1. Add the typed client rescan disposition and session `RescanResult`.
2. Correct mixed active/paused `rescan-all` and add its Go tests.
3. Add the shared QML rescan tracker and move both services to it.
4. Replace mutation publication with explicit protocol publication ordering.
5. Remove the unused wire fields, capability gate, and result revision.
6. Apply lifecycle commands once and add invocation-count tests.
7. Add complete clone isolation coverage and fix request-ID eviction.
8. Update maintained contracts to describe the implemented wire and rescan
   behavior.
9. Rebuild the bundled core only after Go and QML source checks pass.

Keep the Event API, session decomposition, argument-type, client-file, and
visual-model ideas out of these commits. They have separate entry conditions
above.

## Verification gates

Run focused tests while implementing:

```bash
go -C core test ./internal/syncthing ./internal/session ./internal/protocol
go -C core test -race ./internal/session ./internal/protocol
bash tests/core-process.test.sh
bash tests/adapter-service.test.sh
bash tests/rescan-core-loss.test.sh
```

Then run the repository gates already required by the development guide:

```bash
git diff --check
go -C core test ./...
go -C core test -race ./...
go -C core vet ./...
qml6 --apptype core -f tests/run.qml
bash tests/architecture.test.sh
bash tests/native-core-architecture.test.sh
for adapter in dankmaterialshell illogical-impulse caelestia waybar; do
  bash "tests/$adapter-adapter.test.sh"
done
packaging/bundled/build.sh
packaging/bundled/verify.sh
```

The final review must inspect the actual diff for these conditions:

- no source file reads removed wire fields;
- every changed callback uses the new result signature;
- a refreshed action snapshot precedes its result;
- completed and running rescans cannot be conflated;
- paused folders are never sent through the global all-folder request;
- the two service paths use one rescan tracker;
- lifecycle commands execute once;
- no new client interface, daemon, patch protocol, or duplicate state cache was
  introduced;
- maintained documentation describes current code, while this file remains
  clearly labeled as the proposed goal until completion.

## Resulting architecture

The intended result remains small:

```text
native shell presentation
  -> fixed JSONL contract and complete snapshots
  -> one session facade with serialized domain actions
  -> one concrete Syncthing client with private HTTP helpers
  -> Syncthing REST and Event APIs
```

The changes clarify existing behavior. They do not add a new runtime layer.
