# Omarchy service contract

This contract describes the current Omarchy panel-to-service boundary. The
panel, native-backed facade, and member fixture evolve together within a
release; they are not a cross-version interface for retained older services.

## Update boundary

`manifest.json` declares one kept-loaded `service` and one `bar-widget` under
the stable plugin ID `io.github.ilyazar.syncthing`. The panel resolves the
service with `bar.shell.serviceFor(moduleName)`.

The supported update sequence is a normal Omarchy plugin update followed by
a shell restart. Omarchy may retain an older service before that restart;
plugin usability during that interval is unsupported. After restart, the
current panel, service, helpers, and bundled core must work together while
preserving user settings, bar placement, and Syncthing data.

The plugin does not restart the shell automatically. Old helper paths,
aliases, fallback runtimes, and mixed-version bridges are not retained.

## Connection, identity, and models

| Property                 | Type   | Meaning                                |
| ------------------------ | ------ | -------------------------------------- |
| `phase`                  | string | current connection or install phase    |
| `online`                 | bool   | authenticated API state is ready       |
| `refreshing`             | bool   | a visible refresh is open              |
| `canRefresh`             | bool   | core can accept a status refresh       |
| `statusFresh`            | bool   | current core state is fresh            |
| `lastError`              | string | sanitized connection error             |
| `recoveryWarning`        | string | discovery or recovery progress         |
| `baseUrl`                | string | URL used by the Web UI action          |
| `localDeviceId`          | string | live local device ID                   |
| `displayDeviceId`        | string | live or remembered device ID           |
| `displayDeviceName`      | string | live or remembered device name         |
| `devices`                | array  | configured device objects              |
| `folders`                | array  | configured folder objects              |
| `pendingFolders`         | object | offers by folder and device            |
| `folderStatuses`         | object | status keyed by folder ID              |
| `syncingFiles`           | array  | bounded active file tokens             |
| `folderCount`            | int    | configured folder count                |
| `deviceCount`            | int    | configured device count                |
| `connectedDeviceCount`   | int    | local plus connected devices           |
| `folderProblemCount`     | int    | folders with state or pull errors      |
| `syncingFolderCount`     | int    | folders with remaining items           |
| `summaryText`            | string | panel summary for the current state    |

The facade publishes connection, installation, and native-core phases. API
health is authoritative for `online`, including for a healthy external
instance with an inactive unrelated user unit. Native-core availability is
reported separately from Syncthing connection state.

Folder objects expose at least `id`, `label`, `path`, `paused`, `markerName`,
and `devices[].deviceID`. Folder status objects expose at least `state`,
`error`, `errors`, `pullErrors`, `needTotalItems`, `needBytes`, `globalFiles`,
and `globalBytes`. Device objects expose `deviceID`, `name`, and `untrusted`.

The `openWebUi()` method opens the selected GUI. Bundled profiles request the
core's `webui.open` action to grant local desktop access; the default profile
opens `baseUrl` directly. An unavailable desktop connection leaves the ordinary
Web UI accessible without local file actions.

## Installation and lifecycle

| Property                     | Type   | Meaning                        |
| ---------------------------- | ------ | ------------------------------ |
| `installationState`          | string | current installation phase     |
| `installationLabel`          | string | visible installation summary   |
| `executablePath`             | string | discovered executable          |
| `canUseRuntime`              | bool   | runtime can be contacted       |
| `canInstall`                 | bool   | install action is safe         |
| `packageStatus`              | string | installation progress          |
| `packageError`               | string | installation or status error   |
| `serviceAvailable`           | bool   | trusted user unit is available |
| `serviceActive`              | bool   | observed or pending run state  |
| `serviceActionRunning`       | bool   | start or stop is in progress   |
| `canControlService`          | bool   | lifecycle switch may be shown  |
| `controlError`               | string | lifecycle action error         |
| `configuredServiceState`     | string | enabled or disabled preference |
| `probeIntervalSeconds`       | int    | lifecycle probe interval       |
| `serviceUnitFileState`       | string | observed unit-file state       |
| `serviceStateDrift`          | bool   | preference and unit differ     |
| `serviceStateActionRunning`  | bool   | drift action is in progress    |
| `serviceStateMessage`        | string | drift dialog body              |
| `serviceStatePrimaryLabel`   | string | preferred drift action         |
| `serviceStateSecondaryLabel` | string | alternate drift action         |
| `serviceStateWarning`        | string | unsupported observed state     |

Installation phases are `checking`, `existing`, `incomplete`, and `missing`.

For 0.1.8, `serviceAvailable` does not itself grant authority.
`canControlService` is true only for an explicit, target-aware lifecycle
binding. An API-online external instance stays online and hides unrelated
lifecycle controls.

## Folder preparation and mutation

| Property                 | Type   | Meaning                              |
| ------------------------ | ------ | ------------------------------------ |
| `folderMutationBusy`     | bool   | one folder mutation is active        |
| `folderMutationId`       | string | affected ID, or empty for all        |
| `folderMutationAction`   | string | current folder action                |
| `folderMutationError`    | string | current mutation failure             |
| `folderMutationNotice`   | string | successful mutation notice           |
| `recentlyLinkedFolderId` | string | recently resumed folder highlight    |
| `folderPreparationBusy`  | bool   | ID suggestion is in progress         |
| `folderPreparationError` | string | ID suggestion failure                |
| `folderIdSuggestion`     | string | generated ten-character folder ID    |

Folder mutation actions are `add`, `link`, `unlink`, `rescan`, `rescan-all`,
and `forget`.

Only one mutation is accepted at a time. A false method result means the
request was rejected before asynchronous work began. Forgetting removes only
the Syncthing folder record and never local data. Add requires an existing,
canonical, non-overlapping path and a unique ID.

An accepted rescan publishes the stable mutation action and target ID before
the API request starts. The panel derives its optimistic targets from those
fields and the current folder pause state. The host keeps matching buttons
inert, rotates their refresh glyphs, and presents `RESCANNING` until success,
failure, cancellation, or core loss clears the mutation.

## Activity and host settings

| Property               | Type   | Meaning                                 |
| ---------------------- | ------ | --------------------------------------- |
| `syncActivity`         | string | complete visible activity label         |
| `syncActivityDots`     | string | aligned animation frame                 |
| `syncActivityFolderId` | string | folder owning the current file          |
| `syncActivityAction`   | string | `syncing`, `upload`, or `removing`      |
| `syncActivityDetail`   | string | bounded file detail                     |
| `iconStyle`            | string | host preference: `branded` or `themed`  |
| `settingsReady`        | bool   | host settings loaded and valid          |
| `settingsBusy`         | bool   | settings, theme, or removal work active |
| `settingsError`        | string | host settings or theme error            |
| `settingsNotice`       | string | host settings or theme success notice   |

Migration properties are `settingsMigrationOpen` (bool), `settingsCanAutoPort`
(bool), and `settingsMigrationMessage` (string). The message identifies the
actual file, explains compatibility, and previews the mapped preferences.

`RemoteDownloadProgress` is presented as a local upload. Indexed additions and
deletions are classified from current file information. Rename and move are
not inferred.

## Methods

- `refresh(recheckErrors)` refreshes installation and API state. The explicit
  error-recheck form rescans only active folders with reported problems before
  publishing the latest Syncthing state.
- `setRefreshInterval(seconds)` clamps native reconciliation to 60-3600
  seconds.
- `setLegacyThemedIcon(enabled)` seeds the implicit icon preference only.
- `toggleService()` starts or stops an authorized unit.
- `chooseServiceStateAction(index)` applies the selected drift resolution.
- `installSyncthing()` opens the host-owned Omarchy installer.
- `requestFolderIdSuggestion()` requests one new folder ID.
- `setFolderLinked(id, linked)` resumes or pauses a verified folder.
- `rescanFolder(id)` rescans one active folder.
- `rescanAllFolders()` rescans every linked folder.
- `forgetFolder(id)` forgets one verified paused folder.
- `addFolder(path, label, id, devices, offer)` adds one existing local
  directory.
- `clearFolderMutationMessage()` clears the folder error and notice.
- `clearFolderMutationNotice()` clears the folder notice only.
- `openSettings()` opens the host file or its migration dialog.
- `recheckSettings()` reloads and validates the actual file.
- `autoPortSettings()` writes a validated older-format conversion with backup.
- `manualPortSettings()` opens the user file and temporary reference template.
- `cancelSettingsMigration()` dismisses without writing; a warning remains.
- `clearSettingsNotice()` clears the host settings notice.
- `requestSelfRemoval(deleteSettings)` starts native removal after theme
  restoration.

Folder mutation methods and drift selection return whether work was accepted.
Other methods are asynchronous fire-and-observe calls through the properties
above.

## Signals, timing, errors, and cancellation

QML supplies change signals for every property. The panel explicitly observes
`folderIdSuggestionChanged`, `folderMutationNoticeChanged`, and
`folderMutationErrorChanged`. Their timing and meanings are part of this
contract.

Successful folder notices remain available for about ten seconds and are also
sent through the host notification helper. The panel displays notices for ten
seconds, then fades them for 350 milliseconds. A recently linked folder is
highlighted for ten seconds. File activity cycles every 2.5 seconds.

The panel's visible error priority is folder picker, folder mutation,
lifecycle control, package, settings, then connection. Recovery and lifecycle
drift warnings are separate from errors.

There is no user-facing cancel action for an accepted mutation. Service
destruction, target loss, or runtime loss aborts outstanding API requests,
event polling, preparation, and mutation work. A stopped mutation clears busy
state and reports a bounded error when appropriate. Closing the add view is
blocked while its add mutation is active.
