import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../models/SettingsModel.js" as SettingsModel

QtObject {
  id: root

  readonly property string homePath: Quickshell.env("HOME")
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME")
    || homePath + "/.config"
  readonly property string settingsPath: configHome
    + "/omarchy/ilyazar.syncthing/settings.toml"
  readonly property string settingsTemplatePath: localPath(
    Qt.resolvedUrl("../config/settings.toml"))
  readonly property string settingsHelperPath: localPath(
    Qt.resolvedUrl("../scripts/syncthing-settings.sh"))
  readonly property string themeHelperPath: localPath(
    Qt.resolvedUrl("../scripts/syncthing-theme.sh"))
  readonly property string removeHelperPath: localPath(
    Qt.resolvedUrl("../scripts/syncthing-remove.sh"))
  readonly property string pluginRoot: localPath(Qt.resolvedUrl("../../.."))

  property var selectTheme
  property bool runtimeReady: false
  property bool legacyThemedIcon: false
  property bool settingsExists: false
  property string iconStyle: SettingsModel.DefaultIconStyle
  property string webUiTheme: SettingsModel.DefaultWebUiTheme
  property string serviceState: SettingsModel.DefaultServiceState
  property int probeIntervalSeconds:
    SettingsModel.DefaultProbeIntervalSeconds
  property string currentWebUiTheme: ""
  property string guiAssetsPath: ""
  property string error: ""
  property string notice: ""
  property bool busy: false
  property bool migrationOpen: false
  property string migrationError: ""
  property int settingsVersion: SettingsModel.SupportedVersion
  property var migration: ({})
  property string _settingsRaw: ""
  property string _settingsInput: ""
  property bool _migrationPrompted: false
  property bool _migrationCanceled: false
  property bool _hasAcceptedSettings: false
  property bool _settingsLoaded: false
  property bool _settingsValid: false
  property bool _reconciling: false
  property bool _reconcileAgain: false
  property string _preparedTheme: ""
  property bool _openAfterEnsure: false
  property string _settingsAction: ""
  property bool _deleteSettingsAfterRemoval: false

  readonly property bool settingsReady: _settingsLoaded && _settingsValid
  readonly property bool migrationRequired: settingsExists
    && settingsVersion !== SettingsModel.SupportedVersion
  readonly property bool canAutoPort: migrationRequired && !!migration.text
    && !migration.error
  readonly property string migrationMessage: {
    var version = settingsVersion === 0 ? "Unversioned settings"
      : "Settings version " + settingsVersion
    var message = version + " must be updated for version "
      + SettingsModel.SupportedVersion + ".\n\n" + settingsPath
    if (settingsVersion > SettingsModel.SupportedVersion) {
      return message + "\n\nAuto-port cannot downgrade newer settings. "
        + "Use a newer Syncshell or compare manually."
    }
    if (!canAutoPort) return message + "\n\nAuto-port unavailable: "
      + (migration.error || error)
    var values = migration.values
    message += "\n\nIcon:    " + values.iconStyle
      + "\nProbe:   " + values.probeIntervalSeconds + " seconds"
      + "\nWeb UI:  " + values.webUiTheme + "\nService: " + values.serviceState
    if (migration.additions.length) message += "\n\nAdd missing defaults:\n"
      + migration.additions.join("\n")
    var originalPath = backupLocationOutput.text.trim()
    return message + "\n\nYour comments are preserved. Auto-port keeps a backup "
      + "beside the original file under:\n\n"
      + (originalPath ? originalPath + ".before-port.*\n\n* is a unique suffix."
        : "Resolving backup location...")
      + (migrationError ? "\n\n" + migrationError : "")
  }
  readonly property string desiredTheme: webUiTheme === "modern"
    ? "syncshell-modern" : webUiTheme === "omarchy"
      ? "syncthing-omarchy" : "default"
  readonly property bool serviceStateActionRunning:
    settingsProcess.running && _settingsAction === "service-state"

  function localPath(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = value.slice(7)
    return decodeURIComponent(value)
  }

  function loadSettings(raw) {
    var parsed = SettingsModel.parse(raw)
    _settingsValid = false
    _settingsRaw = raw
    settingsVersion = parsed.version
    settingsExists = true
    _settingsLoaded = true
    migration = migrationRequired ? SettingsModel.migrate(raw) : ({})
    if (migrationRequired) backupLocationProcess.running = true
    if (!migrationRequired) migrationOpen = false
    if (parsed.error) {
      _settingsValid = false
      error = _migrationCanceled && migrationRequired
        ? canceledMessage() : "Settings not applied: " + parsed.error
      if (migrationRequired && !_migrationPrompted) {
        _migrationPrompted = true
        migrationOpen = true
      }
      return
    }
    migrationOpen = false
    migrationError = ""
    _migrationPrompted = false
    _migrationCanceled = false
    _hasAcceptedSettings = true
    iconStyle = parsed.iconStyle
    webUiTheme = parsed.webUiTheme
    serviceState = parsed.serviceState
    probeIntervalSeconds = parsed.probeIntervalSeconds
    _settingsValid = true
    error = ""
    scheduleReconcile()
  }

  function useImplicitDefaults() {
    var values = SettingsModel.defaults(legacyThemedIcon)
    settingsExists = false
    settingsVersion = SettingsModel.SupportedVersion
    migrationOpen = false
    migration = ({})
    migrationError = ""
    _migrationPrompted = false
    _migrationCanceled = false
    _hasAcceptedSettings = true
    _settingsLoaded = true
    _settingsValid = true
    iconStyle = values.iconStyle
    webUiTheme = values.webUiTheme
    serviceState = values.serviceState
    probeIntervalSeconds = values.probeIntervalSeconds
    error = ""
    scheduleReconcile()
  }

  function setLegacyThemedIcon(enabled) {
    legacyThemedIcon = enabled === true
    if (!settingsExists) iconStyle = SettingsModel.defaults(legacyThemedIcon).iconStyle
  }

  function openSettings() {
    recheckSettings()
    if (migrationRequired) {
      _migrationPrompted = true
      _migrationCanceled = false
      migrationOpen = true
      return
    }
    if (settingsExists) {
      Quickshell.execDetached([
        "omarchy", "launch", "config-editor", settingsPath
      ])
      return
    }
    if (settingsProcess.running) return
    _openAfterEnsure = true
    _settingsAction = "ensure"
    busy = true
    settingsProcess.command = [
      "bash", settingsHelperPath, "ensure", settingsTemplatePath,
      settingsPath, iconStyle
    ]
    settingsProcess.running = true
  }

  function recheckSettings() { settingsFile.reload() }

  function autoPort() {
    if (!canAutoPort || busy) return
    var checked = SettingsModel.parse(migration.text)
    if (checked.error) { error = checked.error; return }
    _settingsInput = JSON.stringify({
      original: _settingsRaw, replacement: migration.text
    })
    migrationError = ""
    _settingsAction = "migrate"
    busy = true
    settingsProcess.command = ["bash", settingsHelperPath, "migrate", settingsPath]
    settingsProcess.running = true
  }

  function manualPort() {
    if (busy) return
    migrationOpen = false
    migrationError = ""
    _migrationCanceled = false
    _settingsAction = "compare"
    busy = true
    settingsProcess.command = [
      "bash", settingsHelperPath, "compare", settingsTemplatePath, settingsPath
    ]
    settingsProcess.running = true
  }

  function canceledMessage() {
    return "Settings were not upgraded. Update them manually or ask your agent to migrate them. "
      + (_hasAcceptedSettings ? "Using the last valid settings for this session."
        : "Incompatible settings are not applied; status monitoring remains available.")
  }

  function cancelMigration() {
    if (busy) return
    migrationOpen = false
    _migrationPrompted = true
    _migrationCanceled = true
    error = canceledMessage()
  }

  function setServiceState(state) {
    var desired = String(state || "")
    if (["enabled", "disabled"].indexOf(desired) < 0
        || !settingsReady || busy || settingsProcess.running) return false
    _settingsAction = "service-state"
    busy = true
    error = ""
    settingsProcess.command = [
      "bash", settingsHelperPath, "set-service-state", settingsTemplatePath,
      settingsPath, iconStyle, desired
    ]
    settingsProcess.running = true
    return true
  }

  function clearNotice() {
    notice = ""
  }

  function requestSelfRemoval(deletePluginSettings) {
    if (!runtimeReady || !selectTheme || busy) {
      error = "Syncthing must be available for clean removal"
      return
    }
    busy = true
    error = ""
    _deleteSettingsAfterRemoval = deletePluginSettings === true
    if (!guiAssetsPath) {
      finishRemoval("Syncthing did not report its GUI assets path")
      return
    }
    if (ownsTheme(currentWebUiTheme)) {
      selectTheme("default", function() {
        root.startRemovalWorker()
      }, function(actionError) {
        root.finishRemoval(root.apiErrorMessage(actionError))
      })
    } else startRemovalWorker()
  }

  function startRemovalWorker() {
    removalProcess.command = [
      "bash", removeHelperPath, "start", pluginRoot, guiAssetsPath,
      _deleteSettingsAfterRemoval ? "purge" : "preserve"
    ]
    removalProcess.running = true
  }

  function finishRemoval(message) {
    busy = false
    if (message) error = message
  }

  function scheduleReconcile() {
    if (!_settingsLoaded || !_settingsValid || !runtimeReady) return
    reconcileTimer.restart()
  }

  function reconcile() {
    if (!_settingsLoaded || !_settingsValid || !runtimeReady || !selectTheme) return
    if (_reconciling || themeProcess.running) {
      _reconcileAgain = true
      return
    }
    error = ""
    _reconciling = true
    busy = true
    if (!guiAssetsPath) {
      finishReconcile("Syncthing did not report its GUI assets path")
      return
    }
    applyDesiredTheme()
  }

  function applyDesiredTheme() {
    if (!settingsExists && currentWebUiTheme !== "default"
        && !ownsTheme(currentWebUiTheme)) {
      notice = "Keeping Syncthing Web UI theme " + currentWebUiTheme
      finishReconcile("")
      return
    }

    if (webUiTheme === "default") {
      if (ownsTheme(currentWebUiTheme)) {
        setSyncthingTheme("default")
      } else finishReconcile("")
      return
    }

    _preparedTheme = desiredTheme
    themeProcess.command = [
      "bash", themeHelperPath, "prepare", webUiTheme, guiAssetsPath
    ]
    themeProcess.running = true
  }

  function setSyncthingTheme(theme) {
    selectTheme(theme, function() {
      root.notice = theme === "syncthing-omarchy"
        ? "Omarchy Web UI theme applied"
        : theme === "syncshell-modern" ? "Modern Web UI applied"
          : "Syncthing default Web UI theme restored"
      root.finishReconcile("")
    }, function(actionError) {
      root.finishReconcile(root.apiErrorMessage(actionError))
    })
  }

  function ownsTheme(theme) {
    return theme === "syncshell-modern" || theme === "syncthing-omarchy"
  }

  function apiErrorMessage(apiError) {
    return "Could not update Syncthing Web UI: "
      + (apiError ? apiError.message : "Connection failed")
  }

  function finishReconcile(message) {
    if (settingsReady) error = message || ""
    _reconciling = false
    busy = false
    if (_reconcileAgain) {
      _reconcileAgain = false
      reconcileTimer.restart()
    }
  }

  onRuntimeReadyChanged: scheduleReconcile()
  onCurrentWebUiThemeChanged: scheduleReconcile()
  onGuiAssetsPathChanged: scheduleReconcile()
  onLegacyThemedIconChanged: {
    if (!settingsExists) iconStyle = SettingsModel.defaults(legacyThemedIcon).iconStyle
  }

  property FileView settingsFile: FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadSettings(text())
    onLoadFailed: function(fileError) {
      if (fileError === FileViewError.FileNotFound) root.useImplicitDefaults()
      else {
        root._settingsLoaded = true
        root._settingsValid = false
        root.error = "Could not read Syncthing plugin settings: "
          + FileViewError.toString(fileError)
      }
    }
    onFileChanged: reload()
  }

  property Process backupLocationProcess: Process {
    command: ["realpath", "-e", root.settingsPath]
    stdout: StdioCollector { id: backupLocationOutput }
  }

  property Process settingsProcess: Process {
    id: settingsProcess
    command: []
    stdinEnabled: true
    stdout: StdioCollector { id: settingsOutput }
    stderr: StdioCollector { id: settingsErrors }
    onStarted: {
      if (root._settingsAction === "migrate") write(root._settingsInput + "\n")
      root._settingsInput = ""
    }
    onExited: function(exitCode) {
      var action = root._settingsAction
      root.busy = false
      if (exitCode === 0) {
        settingsFile.reload()
        if (root._openAfterEnsure) {
          Quickshell.execDetached([
            "omarchy", "launch", "config-editor", root.settingsPath
          ])
        }
        if (action === "service-state") {
          root.notice = "Syncthing service preference updated"
        } else if (action === "migrate") {
          root.notice = "Settings upgraded. Backup: " + settingsOutput.text.trim()
        } else if (action === "compare") {
          root.notice = "Save your settings to recheck them. "
            + "The temporary template is only a reference."
        }
      } else {
        root.error = settingsErrors.text.trim() || (action === "service-state"
          ? "Could not update Syncthing service preference"
          : "Could not prepare Syncthing plugin settings")
        if (action === "migrate" || action === "compare") root.migrationError = root.error
      }
      root._openAfterEnsure = false
      root._settingsAction = ""
    }
  }

  property Process themeProcess: Process {
    id: themeProcess
    command: []
    onExited: function(exitCode) {
      if (!root.settingsReady) {
        root.finishReconcile("")
      } else if (exitCode !== 0) {
        root.finishReconcile("Could not prepare the " + root.webUiTheme + " Web UI")
      } else if (root._preparedTheme === root.desiredTheme
          && root.currentWebUiTheme !== root._preparedTheme) {
        root.setSyncthingTheme(root._preparedTheme)
      } else {
        root.finishReconcile("")
      }
    }
  }

  property Process removalProcess: Process {
    id: removalProcess
    command: []
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.notice = "Clean removal started"
        root.busy = false
      } else root.finishRemoval("Could not start clean plugin removal")
    }
  }

  property Timer reconcileTimer: Timer {
    interval: 150
    repeat: false
    onTriggered: root.reconcile()
  }

  property Connections themeConnections: Connections {
    target: Color
    enabled: root.webUiTheme === "omarchy"
    function onBackgroundChanged() { root.scheduleReconcile() }
    function onForegroundChanged() { root.scheduleReconcile() }
    function onAccentChanged() { root.scheduleReconcile() }
    function onMutedChanged() { root.scheduleReconcile() }
    function onUrgentChanged() { root.scheduleReconcile() }
  }
}
