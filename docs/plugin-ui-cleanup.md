# Plugin UI cleanup audit

Scope: plugin QML/JavaScript and its test harnesses, based on `180e438`.
Web UI assets and source, Go implementation, and Go tests are excluded.

## Decisions

- Remove `cycleCurrentFolder`: the panel now navigates controls, and only its
  old test still called this function. Test actual dropdown key events instead.
- Remove unused panel forwarding methods for device names, parent directory
  names, and status help. Keep the model functions used by real consumers.
- Remove the old icon-setting forwarding chain: its two branches already yield
  the same default. The settings controller is the single preference owner.
- Reuse `PanelModel.resolveFolderPath` rather than maintain a second copy.
- Share file-URL decoding in the eight-line `shared/Paths.js`. Keep packaging
  explicit so assembled adapters include the helper.
- Share the encrypted-offer predicate: actionable offers and the hidden-offer
  count must agree, including offers from several devices.
- Keep host-specific layouts and form state separate. Similar-looking Omarchy,
  DMS, and Waybar components have different focus, lifecycle, and layout APIs.
  A generic UI factory would add more complexity than it removes.
- Keep cohesive declarative panels intact despite their size. This pass removes
  dead imperative code, not QML object trees solely to meet a line limit.
- Keep explicit settings migration. It is an exercised user-facing operation,
  not a second runtime parser path: incompatible settings are refused until
  converted. No old runtime behavior or new compatibility shim is introduced.

## Test disposition

The least useful static assertions counted a uniquely named root manifest and
checked individual package files. `architecture.test.sh` now validates a
staged installable tree using Omarchy's actual validator. CI already verifies
bundled checksums. No source-text assertion is counted as execution coverage.

Keep these behavioral tests:

- `run.qml`: model transformations, invalid settings, grouped errors, lifecycle
  presentation, and rescan transitions; now included in the plugin UI runner
- dropdown and folder overview: focus, search, stable selection, keyboard
  activation, filters, sorting, and reconciliation
- busy button: disabled and pending actions must not issue duplicate requests
- recovery fixtures: installation recovery, refresh serialization, protocol
  failure, and loss of a core process during a rescan are different failures
  (refresh recovery also exercises rescan API and process loss)
- settings, removal, and palette fixtures: user-file preservation, explicit
  migration, destructive-operation boundaries, and theme refresh
- adapter scripts: execute assembly or patching, rather than merely matching
  source text; they protect deployable imports and reversible configuration
- folder creation: executes extracted methods and verifies missing-directory
  confirmation and immutable submission arguments; brittle extraction is a
  reason to improve this later, not to discard its unique safety checks

`plugin-acceptance.qml` remains owned by the integration harness, not a dead
standalone test. `native-core-architecture.test.sh`, live core/VM acceptance,
Web UI tests, and Go tests are outside this cleanup and remain unchanged.

Run the local plugin suite with:

```sh
bash tests/plugin-ui.test.sh
```

It requires Qt 6 tools, Quickshell, Omarchy, Node, and a desktop session. Tests
run serially because popup focus is shared. The GitHub-hosted contracts job
cannot substitute for this host-specific runtime suite.

## Coverage evidence

Qt 6.11.2's QML profiler and Quickshell 0.3.1 recorded the existing model and
runtime suites before and after the changes. This measures **named function
entry coverage**, not line or branch coverage. Source assertions and the Node
method-extraction fixture are not counted. The denominator includes plugin
sources in `hosts`, `shared`, and `integrations`, including adapter templates.

| Source        | Before           | After            |
|---------------|------------------|------------------|
| QML           | 185/361 (51.25%) | 181/350 (51.71%) |
| JavaScript    | 45/48 (93.75%)   | 48/50 (96.00%)   |
| QML templates | 0/10 (0.00%)     | 0/8 (0.00%)      |
| Total         | 230/419 (54.89%) | 229/408 (56.13%) |

Coverage did not fall under this metric. Four formerly hit methods were
removed or consolidated. Every retained function hit in the baseline was also
hit in the final trace. Unconfigured shell adapters are not claimed as
interactively covered.

Profiling instruments only temporary staged fixtures to stop and flush before
process exit; normal acceptance runs use the unmodified fixtures. An initial
unflushed trace was rejected, not used to justify deletion. Raw profiler files
are development artifacts outside Git.

## Installed-panel verification

Deployed through Neovim's normal check/deploy/restart action, then exercised
with `computer-use-linux` on the live Omarchy panel:

- search narrows results without changing the selected folder or total count
- keyboard activation changes both the selector and the visible folder card
- `l` opens view options; `q` closes only that innermost layer
- side-card text entry accepts `j` and `k`; Tab retains native field navigation
- the real folder chooser returns a decoded local path and derived label
- cancelling the form leaves configuration unchanged; the original selection
  and collapsed panel state were restored

No folder was added, removed, paused, or shared. Runtime logs contain no new
Syncshell error. The temporary input daemon and socket were removed afterward.

## Remaining tooling warnings

`Process.onExited` exposes `QProcess::ExitStatus`, which Quickshell 0.3.1's
QML tooling metadata does not resolve. Qt 6.11.2 reports the same warning for a
standalone process with no Syncshell imports, even with explicitly typed
handler parameters. Extra Qt imports do not fix it.

This is the previously reported Quickshell issue #1218. Do not suppress all
signal-handler diagnostics or replace declarative handlers with manual signal
connections to hide it. A clean raw LSP result requires corrected upstream
metadata. The Neovim check validates staged installation files and lints 61
Omarchy-owned QML/JS files: it exits successfully with only this warning class.
Adapters must be assembled before linting; linting their source templates in
place produces misleading missing-import diagnostics. The changed Caelestia
and Illogical Impulse service templates lint without diagnostics after
assembly. Waybar has the same three `PanelWindow`/`margins` metadata warnings
before and after this pass. DMS packaging passes, but complete static lint
requires its host modules and generated tooling VFS, unavailable here.
