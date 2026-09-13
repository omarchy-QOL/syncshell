import QtQuick
import Quickshell
import "."

QtObject {
  id: root

  required property string pluginRoot
  required property string hostId
  property int probeIntervalSeconds: 15
  property int refreshIntervalSeconds: 60

  readonly property var state: core.snapshot || ({})
  readonly property var connection: state.connection || ({})
  readonly property var counts: state.counts || ({})
  readonly property var activity: state.activity || ({})
  readonly property var currentActivity: activity.current || ({})
  readonly property var webUi: state.webUi || ({})
  readonly property var folders: state.folders || []
  readonly property var devices: state.devices || []
  readonly property var pendingFolders: state.pendingFolders || ({})
  readonly property bool online: core.protocolReady
    && connection.online === true
  readonly property bool refreshing: _refreshRequest !== ""
  readonly property bool busy: _actionRequest !== ""
  readonly property bool folderMutationBusy: busy
  readonly property bool folderPreparationBusy:
    _actionName === "folder.suggest-id"
  readonly property int folderCount: Number(counts.folders || 0)
  readonly property int deviceCount: Number(counts.devices || 0)
  readonly property int connectedDeviceCount:
    Number(counts.connectedDevices || 0)
  readonly property int folderProblemCount:
    Number(counts.folderProblems || 0)
  readonly property int syncingFolderCount:
    Number(counts.syncingFolders || 0)
  readonly property string phase: core.starting ? "core-starting"
    : core.incompatible ? "core-incompatible"
    : core.unavailable && !core.running ? "core-unavailable"
    : String(connection.phase || "discovering")
  readonly property string lastError: actionError || core.lastError
    || String(connection.error && connection.error.message || "")
  readonly property string summaryText: summary()
  readonly property string baseUrl: String(webUi.url || "")
  readonly property string activityText: currentActivity.detail
    ? String(currentActivity.action || "Syncing") + " "
      + String(currentActivity.detail) : ""

  property string actionError: ""
  property string actionNotice: ""
  property string folderIdSuggestion: ""
  property string _refreshRequest: ""
  property string _actionRequest: ""
  property string _actionName: ""
  property string _actionFolderId: ""
  property bool _rescanResultReady: false
  property bool _rescanObserved: false

  signal actionFinished(string action, bool ok, var data, var error)

  function summary() {
    if (phase === "core-starting") return "Starting Syncshell"
    if (phase === "discovering") return "Finding Syncthing"
    if (phase === "loading") return "Reading status"
    if (!online) return connection.authorized === false
      && connection.healthy === true ? "Syncthing authorization failed"
      : "Syncthing unavailable"
    if (folderProblemCount > 0) return folderProblemCount + " folder problem"
      + (folderProblemCount === 1 ? "" : "s")
    if (syncingFolderCount > 0) return syncingFolderCount + " folder"
      + (syncingFolderCount === 1 ? "" : "s") + " syncing"
    return folderCount === 0 ? "No folders configured" : "Up to date"
  }

  function errorText(error, fallback) {
    return String(error && error.message || fallback || "Action failed")
  }

  function folder(folderId) {
    var wanted = String(folderId || "")
    for (var index = 0; index < folders.length; index++) {
      if (String(folders[index].id || "") === wanted) return folders[index]
    }
    return null
  }

  function folderLabel(folderId) {
    var value = folder(folderId)
    return value ? String(value.label || value.id) : String(folderId || "")
  }

  function refresh() {
    if (!core.protocolReady || refreshing || busy) return false
    actionError = ""
    _refreshRequest = core.refresh(function(ok, revision, data, error) {
      root._refreshRequest = ""
      if (!ok) root.actionError = root.errorText(error, "Refresh failed")
    })
    return _refreshRequest !== ""
  }

  function runAction(name, args, notice, folderId) {
    if (!online || busy || refreshing) {
      actionError = online ? "Another operation is already running"
        : "Syncthing must be online"
      return false
    }
    actionError = ""
    actionNotice = ""
    _actionName = name
    _actionFolderId = String(folderId || "")
    _rescanResultReady = false
    _rescanObserved = false
    _actionRequest = core.action(name, args || ({}),
      function(ok, revision, data, error) {
        if (!ok) {
          root.finishAction(false, data, error)
          return
        }
        if (root._actionName === "folder.rescan"
            || root._actionName === "folder.rescan-all") {
          root._rescanResultReady = true
          root.settleRescan()
          return
        }
        if (root._actionName === "folder.suggest-id")
          root.folderIdSuggestion = String(data && data.folderId || "")
        root.actionNotice = String(notice || "")
        root.finishAction(true, data, null)
      })
    if (_actionRequest !== "") return true
    actionError = "Native core is not ready"
    clearAction()
    return false
  }

  function finishAction(ok, data, error) {
    var completed = _actionName
    if (!ok) actionError = errorText(error, "Operation failed")
    clearAction()
    actionFinished(completed, ok, data || null, error || null)
  }

  function clearAction() {
    _actionRequest = ""
    _actionName = ""
    _actionFolderId = ""
    _rescanResultReady = false
    _rescanObserved = false
  }

  function scanning(folderId) {
    var value = folder(folderId)
    return value && String(value.status && value.status.state || "")
      .indexOf("scan") === 0
  }

  function rescanTargetsScanning() {
    if (_actionName === "folder.rescan") return scanning(_actionFolderId)
    if (_actionName !== "folder.rescan-all") return false
    for (var index = 0; index < folders.length; index++) {
      if (!folders[index].paused && scanning(folders[index].id)) return true
    }
    return false
  }

  function settleRescan() {
    if (!busy || (_actionName !== "folder.rescan"
        && _actionName !== "folder.rescan-all")) return
    if (rescanTargetsScanning()) {
      _rescanObserved = true
      return
    }
    if (!_rescanResultReady || !_rescanObserved) return
    actionNotice = _actionName === "folder.rescan-all"
      ? "Rescan complete for all folders"
      : "Rescan complete for " + folderLabel(_actionFolderId)
    finishAction(true, null, null)
  }

  function setFolderPaused(folderId, paused) {
    return runAction(paused ? "folder.pause" : "folder.resume",
      { folderId: folderId }, paused ? "Paused " + folderLabel(folderId)
      : "Resumed " + folderLabel(folderId), folderId)
  }

  function rescanFolder(folderId) {
    return runAction("folder.rescan", { folderId: folderId }, "", folderId)
  }

  function rescanAllFolders() {
    return runAction("folder.rescan-all", {}, "", "")
  }

  function forgetFolder(folderId) {
    return runAction("folder.forget", { folderId: folderId },
      "Forgot " + folderLabel(folderId) + "; directory contents were kept",
      folderId)
  }

  function requestFolderIdSuggestion() {
    folderIdSuggestion = ""
    return runAction("folder.suggest-id", {}, "", "")
  }

  function addFolder(values) {
    var input = values || ({})
    return runAction("folder.add-existing", {
      folderId: String(input.folderId || input.id || ""),
      path: String(input.path || ""),
      label: String(input.label || ""),
      deviceIds: input.deviceIds || input.selectedDeviceIds || [],
      pendingDeviceId: String(input.pendingDeviceId || "")
    }, "Added existing directory", String(input.folderId || input.id || ""))
  }

  function openWebUi() {
    if (!online || !baseUrl) return false
    return Qt.openUrlExternally(baseUrl)
  }

  function configureCore() {
    if (!core.protocolReady) return
    core.configure({
      probeIntervalSeconds: probeIntervalSeconds,
      refreshIntervalSeconds: refreshIntervalSeconds,
      desiredServiceState: "enabled"
    })
  }

  onFoldersChanged: settleRescan()

  property CoreProcess core: CoreProcess {
    pluginRoot: root.pluginRoot
    startupArguments: [
      "--host-id", root.hostId,
      "--probe-interval-seconds", String(root.probeIntervalSeconds),
      "--desired-service-state", "enabled",
      "--lifecycle-kind", "systemd-user",
      "--lifecycle-authorized",
      "--lifecycle-unit", "syncthing.service"
    ]
    onProtocolReadyChanged: if (protocolReady) root.configureCore()
    onRunningChanged: if (!running) {
      if (root._refreshRequest !== "") {
        root._refreshRequest = ""
        root.actionError = "Refresh stopped because the native core exited"
      }
      if (root._actionRequest !== "") {
        root.actionError = "Operation stopped because the native core exited"
        root.finishAction(false, null, {
          code: "core_unavailable", message: root.actionError
        })
      }
    }
  }
}
