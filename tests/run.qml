import QtQuick
import "../hosts/omarchy/models/PanelModel.js" as PanelModel
import "../hosts/omarchy/models/SettingsModel.js" as SettingsModel
import "../hosts/omarchy/models/FacadeModel.js" as FacadeModel
import "../shared"

QtObject {
  id: root

  property int rescanCompletions: 0
  property RescanTracker rescanTracker: RescanTracker {
    onCompleted: root.rescanCompletions++
  }

  function compare(actual, expected, name) {
    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
      throw new Error(name + ": expected " + JSON.stringify(expected)
        + ", got " + JSON.stringify(actual))
    }
  }

  function testPanelModel() {
    var service = {
      localDeviceId: "local",
      folders: [{
        id: "folder",
        label: "Configured label",
        path: "/tmp/truthful-folder",
        devices: [{ deviceID: "local" }]
      }],
      folderStatuses: {
        folder: { state: "idle", globalFiles: 3, globalBytes: 12 }
      }
    }
    var rows = PanelModel.buildFolderRows(service, "/home/test")
    compare(rows[0].label, "truthful-folder", "folder display label")
    compare(PanelModel.folderMeta(rows[0]),
      "3 files · local only · Configured label", "folder metadata")
    compare(PanelModel.folderState(rows[0], ""), "SYNCED", "folder state")
    service.folderStatuses.folder.state = "sync-preparing"
    compare(PanelModel.buildFolderRows(service, "/home/test")[0].syncing,
      false, "preparing state without work is not syncing")
    service.folderStatuses.folder.state = "syncing"
    compare(PanelModel.buildFolderRows(service, "/home/test")[0].syncing,
      true, "concrete syncing state is syncing")
    service.folderStatuses.folder.state = "sync-preparing"
    service.folderStatuses.folder.needTotalItems = 1
    compare(PanelModel.buildFolderRows(service, "/home/test")[0].syncing,
      true, "pending items are syncing")
    compare(PanelModel.folderState(rows[0], "", true), "SYNCING",
      "active folder state")
    compare(PanelModel.folderMeta(rows[0], true),
      "Scanning local changes · Configured label", "rescan folder metadata")
    compare(PanelModel.folderState(rows[0], "", false, true),
      "SCANNING", "optimistic rescan state")
    compare(PanelModel.folderState(rows[0], "", true, true),
      "SCAN+SYNC", "rescan with activity")
    rows[0].scanning = true
    compare(PanelModel.folderState(rows[0], ""), "SYNCED",
      "background scan is not a user rescan")
    compare(PanelModel.folderMeta(rows[0]),
      "3 files · local only · Configured label", "background scan metadata")
    compare(PanelModel.localDeviceName({
      displayDeviceName: "optiplex-sff",
      localDeviceId: "",
      devices: []
    }, "fallback"), "optiplex-sff", "remembered local device name")
  }

  function testFolderErrorDetails() {
    var details = [
      { path: "repo", error: "delete dir: contains ignored files" },
      { path: "repo/child", error: "delete dir: contains ignored files" },
      { path: "other", error: "permission denied" }
    ]
    var service = {
      folders: [{ id: "failed", path: "/tmp/failed", label: "Named folder" },
        { id: "healthy", path: "/tmp/healthy" }],
      folderStatuses: FacadeModel.folderStatuses([
        { id: "failed", status: { state: "idle", pullErrors: 19,
            errors: details } },
        { id: "healthy", status: { state: "idle", errors: [] } }
      ])
    }
    var rows = PanelModel.buildFolderRows(service, "/home/test")
    var failed = PanelModel.folderById(rows, "failed")
    compare(failed.errorDetails, details, "per-file errors reach the panel")
    compare(failed.errorCount, 19, "complete error count reaches the panel")
    compare(PanelModel.folderMeta(failed), details[0].error + " · Named folder",
      "card uses the available reason")
    compare(PanelModel.folderErrorText(failed),
      "delete dir: contains ignored files\n\nrepo\nrepo/child\n\n"
        + "permission denied\n\nother", "identical reasons share paths")
    compare(PanelModel.folderErrorText(PanelModel.folderById(rows, "healthy")),
      "", "healthy selection has no errors")
    failed.error = "folder unavailable"
    compare(PanelModel.folderMeta(failed), "folder unavailable · Named folder",
      "folder summary takes precedence")
    service.folderStatuses.failed = FacadeModel.folderStatus({
      state: "idle", pullErrors: 0, errors: []
    })
    failed = PanelModel.folderById(
      PanelModel.buildFolderRows(service, "/home/test"), "failed")
    compare(failed.problem, false, "fresh healthy status clears the problem")
    compare(failed.errorCount, 0, "fresh healthy status clears the error count")
    compare(PanelModel.folderErrorText(failed), "",
      "fresh healthy status clears old details")
    compare(PanelModel.folderErrorText({ problem: true, errorDetails: [
      { path: "<file>", error: "__proto__" }
    ] }), "__proto__\n\n<file>", "error text remains data")
  }

  function testDeviceModels() {
    var remoteId = "AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-"
      + "GGGGGGG-HHHHHHH"
    var nearbyId = "IIIIIII-JJJJJJJ-KKKKKKK-LLLLLLL-MMMMMMM-NNNNNNN-"
      + "OOOOOOO-PPPPPPP"
    var service = {
      localDeviceId: "LOCAL",
      devices: [
        { deviceID: "LOCAL", name: "chronos", connected: true },
        { deviceID: remoteId, name: "xps", connected: false }
      ],
      folders: [{ id: "sync", devices: [{ deviceID: remoteId }] }],
      pendingDevices: [{
        id: remoteId,
        name: "xps",
        address: "tcp://192.0.2.8:22000"
      }],
      nearbyDevices: [{
        id: nearbyId,
        addresses: ["tcp://192.0.2.9:22000"]
      }]
    }
    var remotes = PanelModel.remoteDeviceRows(service)
    compare(remotes.length, 1, "local device excluded from remote devices")
    compare(remotes[0].label, "xps · 1 folder", "remote folder count")
    compare(remotes[0].connected, false, "remote connection state")
    var pending = PanelModel.pendingDeviceRows(service)
    compare(pending[0].label, "xps wants to connect · AAAAAAA",
      "incoming request label")
    var nearby = PanelModel.nearbyDeviceOptions(service)
    compare(nearby[0], { value: "", label: "Custom Device ID" },
      "custom device source first")
    compare(nearby[1], {
      value: nearbyId,
      label: "IIIIIII · tcp://192.0.2.9:22000"
    }, "nearby device source")
  }

  function testSettingsModel() {
    var current = 'version = 2\n[style]\nicon_style = "themed"\n'
      + 'web_ui_theme = "default"\n[service]\nservice_state = "disabled"\n'
      + 'probe_interval_seconds = 27\n'
    var expected = {
      error: "", version: 2, iconStyle: "themed", webUiTheme: "default",
      serviceState: "disabled", probeIntervalSeconds: 27
    }
    compare(SettingsModel.parse(current), expected, "current settings")
    compare(SettingsModel.defaults(false), {
      iconStyle: "themed", webUiTheme: "omarchy", serviceState: "enabled",
      probeIntervalSeconds: 15
    }, "implicit defaults")
    ;["default", "modern", "omarchy"].forEach(function(theme) {
      compare(SettingsModel.parse(current.replace('"default"', '"' + theme
        + '"')).webUiTheme, theme, "valid Web UI " + theme)
    })
    var invalid = [
      current.replace('"default"', '"oomarchy"'),
      current.replace('"default"', '"dfault"'),
      current.replace('"themed"', '"theme"'),
      current.replace('"disabled"', '"disable"'),
      current.replace('[service]', '[servcie]'),
      current + '[future]\nvalue = [1,,]\n',
      current.replace('icon_style', 'icon_stlye'),
      current.replace('"default"', 'default'),
      current.replace('27', '"27"'), current.replace('27', '0'),
      current.replace('27', '3601'), current.replace('27', '1.5'),
      current + 'service_state = "enabled"\n', current + '[style]\n',
      current.replace('version = 2', 'version = "2"'),
      current.replace('version = 2', 'version = 3'),
      current.replace('web_ui_theme = "default"\n', ''),
      current.replace('version = 2', 'version = 2\nversion = 2')
    ]
    invalid.forEach(function(raw, index) {
      compare(!!SettingsModel.parse(raw).error, true, "invalid settings " + index)
      compare(!!SettingsModel.migrate(raw).error, true, "unsafe migration " + index)
    })
    var older = current.replace('version = 2', 'version = 1 # owner comment')
    compare(!!SettingsModel.parse(older).error, true, "old runtime format refused")
    var migrated = SettingsModel.migrate(older)
    compare(migrated.values, expected, "old preferences survive")
    compare(migrated.text, current.replace('version = 2',
      'version = 2 # owner comment'), "comments survive")
    compare(migrated.additions, [], "no redundant defaults")
    var legacy = '# owner comment\nicon_style = "branded"\n'
      + 'web_ui_theme = "omarchy"\n'
    migrated = SettingsModel.migrate(legacy)
    compare(migrated.values, {
      error: "", version: 2, iconStyle: "branded", webUiTheme: "omarchy",
      serviceState: "enabled", probeIntervalSeconds: 15
    }, "unversioned migration keeps old defaults")
    compare(migrated.additions.length, 2, "missing defaults are listed")
    compare(migrated.text.indexOf('# owner comment') >= 0, true,
      "legacy comment survives")
    var serviceFirst = 'version = 1\n[service]\nservice_state = "disabled"\n'
      + '[style]\nicon_style = "themed"\nweb_ui_theme = "modern"\n'
    migrated = SettingsModel.migrate(serviceFirst.replace(/\n/g, "\r\n"))
    compare(migrated.values.probeIntervalSeconds, 15, "service before style")
    compare(migrated.values.serviceState, "disabled", "partial service preserved")
    compare(migrated.text.replace(/\r\n/g, "").indexOf("\n"), -1,
      "CRLF preserved")
  }

  function testFacadeProjection() {
    var sourceDevices = [{
      id: "local", name: "desktop", untrusted: false, connected: true
    }, {
      id: "remote", name: "phone", untrusted: true, connected: false
    }]
    compare(FacadeModel.devices(sourceDevices), [{
      deviceID: "local", name: "desktop", untrusted: false, connected: true
    }, {
      deviceID: "remote", name: "phone", untrusted: true, connected: false
    }], "device projection")
    compare(FacadeModel.folderStatuses([{
      id: "folder",
      status: {
        state: "error",
        errors: [{ path: "file", error: "denied" }],
        pullErrors: 2
      }
    }]).folder.errors, 1, "folder error projection")
    compare(FacadeModel.truncationWarning({}), "", "complete state warning")
    compare(FacadeModel.truncationWarning({ folderErrors: 1 }), "",
      "folder detail limits are reported with the errors")
    compare(FacadeModel.truncationWarning({ folders: 1 }),
      "Some Syncthing items exceed panel limits; use the Web UI for the "
        + "hidden entries", "truncated state warning")
  }

  function testDriftPresentation() {
    compare(FacadeModel.lifecyclePresentation({
      available: true,
      targetMatch: false,
      canControl: false,
      canStart: false
    }), {
      available: false,
      controllable: false
    }, "external lifecycle hidden")
    compare(FacadeModel.lifecyclePresentation({
      available: true,
      targetMatch: true,
      classification: "external",
      canControl: false,
      canStart: false
    }), {
      available: false,
      controllable: false
    }, "online inactive unit hidden")
    compare(FacadeModel.lifecyclePresentation({
      available: true,
      targetMatch: true,
      canControl: true,
      canStart: false
    }), {
      available: true,
      controllable: true
    }, "trusted lifecycle shown")
    var decision = FacadeModel.driftDecision("enabled", {
      unitFileState: "disabled",
      activeState: "inactive"
    })
    compare(decision.status, "drift", "drift status")
    compare(decision.first.side, "config", "inactive preferred side")
    compare(decision.second.side, "system", "inactive alternate side")
    compare(FacadeModel.driftDecision("enabled", {
      unitFileState: "enabled",
      activeState: "active"
    }).status, "aligned", "aligned state")
  }

  function testRescanTracker() {
    compare(rescanTracker.acceptResult({
      state: "completed",
      targetFolderIds: ["folder"],
      runningFolderIds: []
    }, []), true, "fast rescan result accepted")
    compare(rescanCompletions, 1, "fast rescan completes immediately")
    compare(rescanTracker.acceptResult({
      state: "running",
      targetFolderIds: ["folder", "other"],
      runningFolderIds: ["folder"]
    }, ["folder"]), true, "long rescan result accepted")
    compare(rescanTracker.runningFolderIds, ["folder"],
      "running rescan target retained")
    compare(rescanCompletions, 1, "running rescan remains pending")
    rescanTracker.reconcile(["other"])
    compare(rescanCompletions, 2, "long rescan completes after target scan")
    compare(rescanTracker.acceptResult({
      state: "running",
      targetFolderIds: ["folder"],
      runningFolderIds: ["other"]
    }, ["other"]), false, "unrelated running target rejected")
    compare(rescanCompletions, 2, "invalid result does not complete")
  }

  Component.onCompleted: {
    try {
      testPanelModel()
      testFolderErrorDetails()
      testDeviceModels()
      testSettingsModel()
      testFacadeProjection()
      testDriftPresentation()
      testRescanTracker()
      console.log("all QML model tests passed")
      Qt.exit(0)
    } catch (error) {
      console.error(error)
      Qt.exit(1)
    }
  }
}
