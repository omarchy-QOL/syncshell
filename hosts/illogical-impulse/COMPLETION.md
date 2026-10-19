# Native UI/UX completion evidence

Status: pre-host corrective implementation complete, native validation
pending. The implemented corrections and offline evidence are recorded below.
Native compositor/two-peer acceptance is still required in both families.

Reference: `hosts/omarchy/` at `2e12032`. Implementation: uncommitted work on
`feat-illogical-native-port`, based on that revision. The earlier 2,937-LOC
implementation and its completion claim are superseded. This report records
behavior, not filename or LOC equivalence.

## Evidence and scope

Paths below are relative to this repository. `I` means
`hosts/illogical-impulse`; `O` means `hosts/omarchy`. In the tables, production
paths are under `I`; reference filenames are under `O/ui` unless specified.
Every production workflow uses the same controller/model with the family's
native controls. A shared test label in both columns means that sequence ran
separately against each family, not that one family substitutes for the other.

- **N**: `tests/illogical/native-components.qml`, driven by
  `tests/illogical-native.test.sh`. Production `PanelPane`, native buttons,
  fields, selectors and `DirectoryPicker`; mouse/key input and assertions on
  content, focus, enabled states and exact mock-service arguments. Passed in
  `/tmp/ii-parity-final4`: 55 input stages per family, including rendered
  offline/TLS/authentication recovery and empty/no-match selectors. Captures
  are in its `captures/` directory; paired normal form, stale diagnostics and
  narrow/large-text menu images were inspected.
- **R**: `tests/illogical/real-core.qml` and `test_real_core.py`, 42 production
  input stages per family. Real Go child against disposable localhost API.
  Exact mutation counts/targets, resulting configuration, file preservation,
  profile recovery/cleanup and process exit are asserted. Passed in
  `/tmp/ii-real-final2/{ii,waffle}`; each contains `runtime.log` and
  `mutations.json`.
- **M**: `tests/illogical/tst_PanelController.qml`, `tst_ParityModels.qml`,
  `tst_ThemePaletteController.qml`; 30 QtTest results passed in
  `/tmp/ii-final-models.txt`. Pure model/controller evidence supplements N/R.
- **O**: `tests/illogical-owner.test.sh`, `owner-lifetime.qml` and delayed
  `worker-mock.py`. Passed in `/tmp/ii-final-owner.txt`: retained drafts,
  frozen confirmations and in-flight actions across family changes/closure;
  disable/enable, reload and teardown; three real child PIDs with no overlap
  or surviving worker. Layered popup stays closed in this fixture.
- **S**: SDK-aware native import/type validation passed in
  `/tmp/ii-final-sdk.txt`. Native dependency/API preflight includes selection
  assets, Material/Fluent text/icons, progress, scrollbars, help, surfaces and
  QtQuick Effects. No upstream libraries are shipped as a fork.
- **P**: ten disposable installer tests and 30 model results passed in
  `/tmp/ii-final-installer.txt`. Pinned-tree check/install/repeat/byte-exact
  removal passed in
  `/tmp/ii-final-pinned-install.txt`.
- **C**: Go unit and race suites passed; shared process/adapter fixtures passed
  in `/tmp/ii-final-core-process.txt` and `/tmp/ii-final-adapter-service.txt`.
  These prove shared protocol, recovery and authority, not rendered parity.

N coverage groups used below:

- **N-menu**: duplicate basenames and metadata search, stable IDs, non-reflowing
  bounded popup, nested filter/reset/query retention, hidden selections,
  40 measured rows, selected-row visibility at narrow width/large text,
  keyboard scrolling, outside dismissal and ordinary Tab.
- **N-form**: real form input, generation failure/retry, picker accept/cancel,
  missing-directory confirmation, repeated Save rejection, early device
  validation, nearby choice, immutable accepted ID/address, clipboard,
  failed action retention, composite offer dismissal and both sharing forms.
- **N-state**: initial selection/totals, disabled help, detailed/stale errors
  with shown/total counts, activity roles, native tab synchronization, hidden
  shortcut suppression, spatial navigation, retained drafts and reconstructed
  presentation/selector intent. Service menu skips unavailable choices and
  submits the frozen confirmation with Cancel initially focused.
- **N-settings**: interval validation, saved versus actual theme, explicit
  same-choice reapply, failure retention, real filesystem permission failure
  and unchanged-draft retry, keyboard toggle/directional navigation.

## G01-G15 behavior matrix

Each row lists the required outcome, production path and separate family
execution. Native limitations apply independently to each family, as recorded
in the last two columns and expanded after the component inventory.

| Item | Reference behavior / production correction                                                                                                                                     | ii evidence                                                | Waffle evidence                                            | ii remaining | Waffle remaining |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------- | ---------------------------------------------------------- | ------------ | ---------------- |
| G01  | Identity, totals and state-specific icons: `ui/PanelStatus.qml`, `IllogicalBarEntry.qml`, `ui/MonoIcon.qml`, `models/PanelModel.js`                                            | N-state, M icons; both bar gestures                        | N-state, M icons; both bar gestures                        | H1, H2       | H1, H2           |
| G02  | Detailed scan/sync/device/share/activity and stale semantics: `models/PanelModel.js`, `ui/{FolderCard,DeviceCard,ActivityText}.qml`                                            | N-state, R pause/resume, M statuses                        | N-state, R pause/resume, M statuses                        | H1           | H1               |
| G03  | Rich anchored search/multi-select with stable identity: `ui/{SyncshellDropdown,SyncshellMultiSelect,FolderSelector}.qml`, native `NativeChoice.qml`                            | N-menu, R selections                                       | N-menu, R selections                                       | H2           | H2               |
| G04  | Contextual actions, mixed filters/sort/reset: `ui/{FolderOverview,RemoteDevices,FolderViewOptions}.qml`, native `NativeSelectionMark.qml`                                      | N-menu, R contextual actions, M sort                       | N-menu, R contextual actions, M sort                       | H1           | H1               |
| G05  | Spatial/Tab navigation, editor/menu precedence, focus scrolling: `ui/PanelPane.qml`, `models/PanelNavigation.js`, selector and settings controls                               | N-menu, N-state, N-settings                                | N-menu, N-state, N-settings                                | H2           | H2               |
| G06  | Aggregate errors, affected path, truncation/freshness and reveal: `ui/MoreDetails.qml`, `PanelController.showDiagnostics`, model diagnostics                                   | N-state; R refresh clears errors                           | N-state; R refresh clears errors                           | H1           | H1               |
| G07  | Folder ID preparation, offers, labels, validation and directory creation: `ui/AddFolderForm.qml`, controller generation ownership                                              | N-form, R overlap/create/accept, M encrypted/stale results | N-form, R overlap/create/accept, M encrypted/stale results | H2, H3       | H2, H3           |
| G08  | Normalize/validate IDs, manual/nearby choices, frozen accepted identity: `ui/{AddRemoteDeviceForm,AcceptRemoteDeviceForm}.qml`, model validation                               | N-form, R device add/accept                                | N-form, R device add/accept                                | H3           | H3               |
| G09  | Initial selections and compact invitations with composite offer IDs: `ui/PendingInvitations.qml`, controller reconciliation                                                    | N-state/N-form, R accept/dismiss, M offer identity         | N-state/N-form, R accept/dismiss, M offer identity         | H3           | H3               |
| G10  | Both sharing directions, hidden selections, pending acceptance and no-op prevention: `ui/{FolderSharingForm,DeviceFoldersForm}.qml`                                            | N-form, R mutations, M new-share reconciliation            | N-form, R mutations, M new-share reconciliation            | H3           | H3               |
| G11  | Error-aware refresh, scoped notices, explicit busy/confirmation/copy feedback: `IllogicalService.qml`, model actions, `ui/{PanelFooter,CompactConfirmDialog,IdCopyButton}.qml` | N-form/N-state, R refresh/rescan/results                   | N-form/N-state, R refresh/rescan/results                   | H2, H3       | H2, H3           |
| G12  | Durable drafts/menus, logical focus restoration and bounded geometry: controller, `IllogicalHost.qml`, `IllogicalPanel.qml`, `ui/PanelPane.qml`                                | N-state/N-menu, M geometry, O                              | N-state/N-menu, M geometry, O                              | H2           | H2               |
| G13  | Native roles, persistent labels, help, accessible icons and measured rows: `ui/{FormField,InfoPair,DisabledHelp}.qml`, native wrappers                                         | N-menu/N-form/N-state, S                                   | N-menu/N-form/N-state, S                                   | H1           | H1               |
| G14  | Private settings, explicit profile retry/cleanup and native removal adaptation: settings/palette controllers, `ui/SettingsMenu.qml`, checked installer                         | N-settings, R profile failure/retry/cleanup, M palette, P  | N-settings, R profile failure/retry/cleanup, M palette, P  | H3, H4       | H3, H4           |
| G15  | Production input instead of construction-only evidence: `PanelPane`/`DirectoryPicker` used by N/R; exact API and PID assertions                                                | N, R, O, M, S, P, C                                        | N, R, O, M, S, P, C                                        | H1-H4        | H1-H4            |

## All 32 reference UI responsibilities

The native limitations column applies to ii and Waffle separately. Evidence
labels retain the family separation shown in the preceding matrix. Entries
marked adaptation are deliberate requirements of the original contract.

| Reference                    | Required outcome / production mapping under I                                          | ii evidence                   | Waffle evidence               | Remaining for each |
| ---------------------------- | -------------------------------------------------------------------------------------- | ----------------------------- | ----------------------------- | ------------------ |
| PanelStatus.qml              | Identity, totals, service; `ui/PanelStatus.qml`                                        | N-state                       | N-state                       | H1/H2              |
| InfoPair.qml                 | Aligned labels, wrapping values; `ui/InfoPair.qml`                                     | N-state, captures             | N-state, captures             | H1                 |
| ActivityText.qml             | Upload/removal/current/stale text; `ui/ActivityText.qml`                               | N-state                       | N-state                       | H1                 |
| FolderCard.qml               | Detailed folder state, open/copy/rescan/recheck/forget; `ui/FolderCard.qml`            | N-form/N-state, R             | N-form/N-state, R             | H1/H3              |
| DeviceCard.qml               | Identity/address/rates, connectivity/pause/share state; `ui/DeviceCard.qml`            | N-form, R, M                  | N-form, R, M                  | H1/H3              |
| FolderOverview.qml           | Selector plus contextual folder actions; `ui/FolderOverview.qml`                       | N-menu, R                     | N-menu, R                     | H1                 |
| RemoteDevices.qml            | Selector plus add/folders/remove; `ui/RemoteDevices.qml`                               | N-form, R                     | N-form, R                     | H1                 |
| MoreDetails.qml              | Errors/freshness/endpoint/version/installation help; `ui/MoreDetails.qml`              | N-state, R recheck            | N-state, R recheck            | H1/H3              |
| FolderSelector.qml           | Rich folder choice and view access; `ui/FolderSelector.qml`                            | N-menu                        | N-menu                        | H2                 |
| SyncshellDropdown.qml        | Anchored searchable native menu; `ui/SyncshellDropdown.qml`                            | N-menu                        | N-menu                        | H2                 |
| SyncshellMultiSelect.qml     | Hidden selections and mixed All; `ui/SyncshellMultiSelect.qml`                         | N-form, M                     | N-form, M                     | H2                 |
| FolderViewOptions.qml        | Groups, sort/reset, nested dismissal; `ui/FolderViewOptions.qml`                       | N-menu, M                     | N-menu, M                     | H2                 |
| AddFolderForm.qml            | ID/offer/path/sharing, validation/picker/create; `ui/AddFolderForm.qml`                | N-form, R, M                  | N-form, R, M                  | H2/H3              |
| AddRemoteDeviceForm.qml      | Manual/nearby validated device draft; `ui/AddRemoteDeviceForm.qml`                     | N-form, R                     | N-form, R                     | H3                 |
| AcceptRemoteDeviceForm.qml   | Read-only request ID/address, editable name/copy; `ui/AcceptRemoteDeviceForm.qml`      | N-form, R                     | N-form, R                     | H3                 |
| FolderSharingForm.qml        | Explicit remote selections including local-only; `ui/FolderSharingForm.qml`            | N-form, R                     | N-form, R                     | H3                 |
| DeviceFoldersForm.qml        | Confirmed/unconfirmed groups and safe removal; `ui/DeviceFoldersForm.qml`              | N-form, R, M                  | N-form, R, M                  | H3                 |
| CompactConfirmDialog.qml     | Cancel first, frozen args, repeat guard; `ui/CompactConfirmDialog.qml`                 | N-form/N-state, R, O          | N-form/N-state, R, O          | H2                 |
| ChoiceDialog.qml             | Service choices/confirmation; adapted in `ui/PanelStatus.qml`                          | N-state, C lifecycle          | N-state, C lifecycle          | H3                 |
| BusyButton.qml               | Native enabled/busy feedback; `ui/BusyButton.qml`                                      | N-form/N-state                | N-form/N-state                | H1                 |
| SquareActionButton.qml       | Compact accessible native icon action; `ui/SquareActionButton.qml`                     | N-form, bar input             | N-form, bar input             | H1                 |
| IdCopyButton.qml             | Exact clipboard ID and durable feedback; `ui/IdCopyButton.qml`                         | N-form                        | N-form                        | H2                 |
| InlineFormHeader.qml         | Persistent heading and explicit Cancel; `ui/InlineFormHeader.qml`                      | N-form                        | N-form                        | H1                 |
| SyncthingPanelPopup.qml      | Main order/content/navigation/footer; `ui/SyncthingPanelPopup.qml`, `ui/PanelPane.qml` | N, R                          | N, R                          | H1/H2              |
| SideCardMenu.qml             | Adjacent retained workflow; `ui/SideCardMenu.qml`, `IllogicalPanel.qml`                | N-form/N-state, M geometry, O | N-form/N-state, M geometry, O | H2                 |
| SettingsMenu.qml             | Intervals/icon/Web UI, save/cancel/recovery; `ui/SettingsMenu.qml`                     | N-settings, R, M              | N-settings, R, M              | H1/H3              |
| SelfRemovalDialog.qml        | Adapted: profile cleanup and checked stopped-shell removal                             | R cleanup, P                  | R cleanup, P                  | H4                 |
| MonoIcon.qml                 | State-specific native tinted icon; `ui/MonoIcon.qml`                                   | M icons, S                    | M icons, S                    | H1 tint/render     |
| SyncshellToolTip.qml         | Native contextual help; family `NativeToolTip.qml`                                     | N disabled help, S            | N disabled help, S            | H1                 |
| TooltipButton.qml            | Help plus action; `ui/BusyButton.qml`, `ui/DisabledHelp.qml`                           | N-form/N-state                | N-form/N-state                | H1                 |
| TooltipPanelActionButton.qml | Help on native icon controls; native `NativeIconButton.qml`                            | N bar/actions, S              | N bar/actions, S              | H1                 |
| UiConstants.js               | Adapter-owned notice/copy timing and family metrics                                    | N feedback, R notices         | N feedback, R notices         | H1 timing feel     |

Also mapped: `O/OmarchyPanel.qml` becomes owner/window/controller boundaries;
`O/models/{PanelModel,PanelNavigation}.js` become the adapter's models;
`O/controllers/{SettingsController,ThemePaletteController}.qml` become private
settings and ownership-safe palette controllers. The production Qt picker
replaces the Omarchy picker helper. Go remains the validation/action authority.

## Explicit adaptations and remaining native acceptance

Omarchy TOML migration and package commands are replaced by versioned private
JSON and installation diagnosis/help. There is no claim of automatic package
installation on ii. Removal uses checked `manage.py` with the target shell
stopped, after owned-profile cleanup; it preserves private settings. No
in-process self-removal or repeated reclaim of another adapter's theme exists.

- **H1, both families:** the offscreen software renderer cannot validate
  shader tint, translucent surfaces, shadows, native motion or actual fonts.
  Material Symbols is absent here; fallback font renders some symbol names as
  text. Waffle effects can leave popup backgrounds transparent. The production
  native types are retained; no alternate software-only UI is introduced.
  Next: inspect matching states on the pinned host in light/dark/translucent
  themes, normal/large text and fractional scale. Capture paired images.
- **H2, both families:** fixtures use ordinary offscreen Windows and the real
  content/picker; they do not execute layered-window compositor grabs. The
  owner fixture keeps its layered popup closed. Next: test Material shared
  focus registration and Waffle local grabs, nested Escape/outside clicks,
  picker return, sidebar/action-centre competition, lock/overview, all six
  supported placements, auto-hide/app layouts, two monitors/output removal,
  edge flip/stacking and family switches with each retained workflow. Pure
  geometry tests cover all four edges, both family sizes and three widths,
  including tall forms, on-screen bounds and non-overlapping panes.
- **H3, both families:** fake API and Go tests prove request/state/authority
  behavior, not live Syncthing synchronization or the intended host's desktop
  URL/file handlers and systemd setup. Next: disposable two-peer configuration,
  every mutation/invitation/profile choice, file hashes, real service authority,
  offline startup/restart and recovery. Never use personal folders.
- **H4, both families:** disposable install/crash-recovery evidence does not
  run the real shell supervisor through replacement. Next: follow README
  stop/install/restart and cleanup/stop/remove/restart commands on the intended
  host, verify one worker and no orphan windows, timers or user-data changes.

Native acceptance is pending for each H-item in each family. It is not waived
by green offline tests. The executable has been exercised on Linux x86_64;
other architectures are not accepted by cross-compilation alone.

## Diagnostics and regression boundaries

The pinned `WTextField.qml:15` QColor-to-QQuickColorGroup warning remains
upstream. N also permits exactly two deliberate settings write-failure
warnings, and requires both corresponding retained-draft assertions. Other
warnings fail the fixture. SDK exclusions are limited to dynamic token/Loader
metadata and Quickshell's runtime-created PanelWindow backend.

One unchanged baseline Node assertion in `tests/device-sharing.test.mjs`
expects `(acceptance pending, or device offline)` while Omarchy emits
`(acceptance pending/device offline)`. The test and all `hosts/omarchy` sources
are byte-identical to HEAD. It is recorded, not weakened or silently fixed.

Earlier final-run attempts exposed a missed multi-select keyboard step and a
real-core Save step without a backend error. The former passed with an
explicit popup-focus assertion on subsequent runs. The latter prompted a
guard against periodic refresh disabling a control during focus scrolling:
the fixture waits for enabled state at mouse delivery, without replaying a
mutation. Both families passed the complete subsequent real-core run; the
precise cause of the earlier missed input was not independently established.
Real-core failures retain their capture and API log. These harness observations
do not establish compositor focus correctness; H2 remains open.

## Final deliverables and reproduction

The installable payload is `dist/illogical-impulse/`; `build.json` identifies
base revision `2e120321a8126bc778d5e3659cd5327a33c729bb`, uncommitted source,
Linux x86_64 and the Go toolchain. `SHA256SUMS.json` records every payload file
except the checksum manifest itself. Final assembly and digest verification
are recorded in `/tmp/ii-final-bundle.txt`. The source branch remains
`feat-illogical-native-port`; nothing was committed, pushed or published.
The original `dev` checkout remains clean.

Use the exact build/install/enable/disable/removal commands in the host
[README](README.md). Compatibility metadata records source, shapes and
Quickshell pins; offline validation used Quickshell 0.3.1 / Qt 6.11.2 on
Linux x86_64. Hyprland 0.56.2 was not exercised by the isolated fixtures.
The old overlay/templates are removed and their active consumers replaced.

Pre-host completion does not assert native acceptance. H1-H4 above state the
missing prerequisite and next action independently for both presentations.
No missing workflow implementation is assigned to that native handoff.
