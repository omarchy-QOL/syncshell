import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "ui"
import "ui/UiConstants.js" as UiConstants
import "models/PanelModel.js" as PanelModel
import "models/ThemePaletteModel.js" as ThemePaletteModel

Panel {
  id: root

  ipcTarget: moduleName

  readonly property var syncthing: bar && bar.shell && moduleName
    ? bar.shell.serviceFor(moduleName) : null
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color warning: syncthing
    ? syncthing.warning : ThemePaletteModel.DefaultYellow
  readonly property color success: syncthing
    ? syncthing.success : ThemePaletteModel.DefaultGreen
  readonly property color syncActivityColor: syncthing
    ? syncthing.syncActivityColor : ThemePaletteModel.DefaultCyan
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string homePath: Quickshell.env("HOME")
  readonly property string folderPickerScript: localPathFromUrl(
    Qt.resolvedUrl("scripts/syncthing-folder-picker.sh"))
  readonly property bool folderPickerRunning: folderPickerProcess.running
  property bool moreOpen: false
  property bool settingsMenuOpen: false
  property bool removalConfirmOpen: false
  property int settingsSelectedIndex: 0
  property bool addOpen: false
  property bool addIdEdited: false
  property bool addLabelFromOffer: false
  property bool addSubmissionPending: false
  property bool folderShareOpen: false
  property bool preserveStateForFolderPicker: false
  property string currentFolderId: ""
  property string selectedPendingOffer: ""
  property string folderConfirmAction: ""
  property string folderConfirmId: ""
  property var folderCreationArgs: null
  readonly property bool folderConfirmOpen: folderConfirmAction !== ""
  property string deviceConfirmAction: ""
  property string deviceConfirmId: ""
  property string deviceConfirmName: ""
  readonly property bool deviceConfirmOpen: deviceConfirmAction !== ""
  property string folderPickerOutput: ""
  property string folderPickerError: ""
  property string displayedNotice: ""
  property bool noticeShown: false
  readonly property var folderRows: buildFolderRows()
  readonly property var currentFolderRow: folderById(currentFolderId)
  readonly property bool compactFolders: folderRows.length >= 5
  readonly property string displayedFolderId: compactFolders
    && visibleSyncActivity !== "" && syncthing
    && folderById(syncthing.syncActivityFolderId)
    ? syncthing.syncActivityFolderId : currentFolderId
  readonly property var visibleFolderRows: compactFolders
    ? (folderById(displayedFolderId) ? [folderById(displayedFolderId)] : [])
    : folderRows
  readonly property var pendingOfferRows: pendingOfferOptions()
  readonly property double trackedBytes: folderTotal("globalBytes")
  readonly property int trackedFiles: folderTotal("globalFiles")
  readonly property int scanningFolderCount: folderStateCount("scanning")
  readonly property int pausedFolderCount: folderStateCount("paused")
  readonly property int rescannableFolderCount:
    Math.max(0, folderRows.length - pausedFolderCount)
  readonly property bool rescanMutationBusy: syncthing
    && syncthing.folderMutationBusy
    && (syncthing.folderMutationAction === "rescan"
      || syncthing.folderMutationAction === "rescan-all")
  readonly property bool syncInProgress: syncthing
    ? syncthing.syncingFolderCount > 0 || syncthing.syncingFiles.length > 0
      || rescanMutationBusy
    : false
  readonly property bool busy: syncthing
    ? syncthing.refreshing || syncInProgress
    : false
  readonly property bool hasProblems: syncthing
    ? syncthing.folderProblemCount > 0 : false
  readonly property string iconVariant: {
    if (!syncthing || !syncthing.canUseRuntime
        || syncthing.phase.indexOf("core-") === 0) return "notify"
    if (syncthing.serviceAvailable && !syncthing.serviceActive) return "pause"
    if (syncthing.phase === "error" || hasProblems) return "notify"
    if (busy) return "sync"
    return "default"
  }
  readonly property bool legacyThemedIcon:
    setting("themedIcon", true) === true
  readonly property bool themedIcon: syncthing
    ? syncthing.iconStyle === "themed" : legacyThemedIcon
  readonly property url syncthingIconSource: Qt.resolvedUrl(
    "../../assets/status-" + iconVariant + ".svg")
  readonly property url themedIconSource: Qt.resolvedUrl(
    "../../assets/mono/status-" + iconVariant + ".svg")
  readonly property string tooltip: {
    if (!syncthing) return "Syncthing unavailable"
    if (iconVariant === "sync" && syncInProgress) {
      return "Syncthing: Sync in progress..."
    }
    return "Syncthing: " + syncthing.summaryText
  }
  readonly property string toggleHint: syncthing && syncthing.serviceActive
    ? "Stop syncing" : "Start syncing"
  readonly property bool managedStop: syncthing
    && syncthing.serviceAvailable && !syncthing.serviceActive
  readonly property string visibleError: {
    if (folderPickerError) return folderPickerError
    if (!syncthing) return ""
    var quiet = (managedStop || syncthing.serviceActionRunning)
      && syncthing.phase.indexOf("core-") !== 0
    return syncthing.folderMutationError
      || syncthing.packageError
      || syncthing.settingsError
      || syncthing.controlError
      || ((quiet || syncthing.installationState === "missing")
        ? "" : syncthing.lastError) || ""
  }
  readonly property string visibleNotice: syncthing
    ? syncthing.folderMutationNotice || syncthing.settingsNotice : ""
  readonly property int visibleNoticeDurationMs: syncthing
    && syncthing.folderMutationNotice !== ""
    ? syncthing.folderMutationNoticeVisibleMs : UiConstants.NOTICE_VISIBLE_MS
  readonly property string visibleWarning: {
    if (syncthing && syncthing.installationState === "missing")
      return "Syncthing is not installed. Open More to install it."
    if (managedStop) return syncthing.summaryText
    return syncthing
      ? syncthing.recoveryWarning || syncthing.serviceStateWarning : ""
  }
  readonly property bool serviceStateDialogOpen: syncthing
    && syncthing.serviceStateDrift
  readonly property bool settingsMigrationOpen: syncthing
    && syncthing.settingsMigrationOpen

  onSettingsMigrationOpenChanged: {
    if (settingsMigrationOpen) {
      closeTransientViews()
      settingsMenuOpen = false
      open()
    }
  }
  readonly property string visibleSyncActivity: syncthing
    ? syncthing.syncActivity : ""
  readonly property string visibleSyncDots: syncthing
    ? syncthing.syncActivityDots : ""
  readonly property string visibleSyncAction: syncthing
    ? syncthing.syncActivityAction : ""
  readonly property string visibleSyncDetail: syncthing
    ? syncthing.syncActivityDetail : ""
  readonly property string localDeviceName: PanelModel.localDeviceName(
    syncthing, Quickshell.env("HOSTNAME"))

  function showNotice(message, visibleMs) {
    displayedNotice = message
    noticeShown = true
    noticeFadeTimer.stop()
    noticeDisplayTimer.interval = Number(visibleMs) > 0
      ? Math.round(Number(visibleMs)) : UiConstants.NOTICE_VISIBLE_MS
    noticeDisplayTimer.restart()
  }

  function chooseServiceStateAction(index) {
    if (syncthing) syncthing.chooseServiceStateAction(index)
  }

  function configureService() {
    if (!syncthing) return
    syncthing.setRefreshInterval(setting("refreshIntervalSec", 60))
    syncthing.setLegacyThemedIcon(legacyThemedIcon)
  }

  function buildFolderRows() {
    return PanelModel.buildFolderRows(syncthing, homePath)
  }

  function folderTotal(key) {
    return PanelModel.total(folderRows, key)
  }

  function folderStateCount(key) {
    return PanelModel.stateCount(folderRows, key)
  }

  function formatCount(value) {
    return PanelModel.formatCount(value)
  }

  function formatBytes(value) {
    return PanelModel.formatBytes(value)
  }

  function folderErrorText(folder) {
    return PanelModel.folderErrorText(folder)
  }

  function showFolderErrors(folderId) {
    currentFolderId = folderId
    moreOpen = true
    Qt.callLater(function() { popup.scrollToMore() })
  }

  function scrollToMore() {
    popup.scrollToMore()
  }

  function scrollToTop() {
    popup.scrollToTop()
  }

  function toggleFolderSharing() {
    var opening = !folderShareOpen
    if (opening && addOpen) closeAddFolder()
    folderShareOpen = opening
    if (folderShareOpen) Qt.callLater(function() { popup.scrollToMore() })
  }

  function showBarTooltip() {
    if (!bar || !button.tooltipHovered || tooltip === "") return
    bar.clearTooltip()
    bar.tooltipRequest += 1
    bar.tooltipTarget = button
    bar.tooltipText = tooltip
    bar.tooltipShown = true
  }

  function folderMeta(folder) {
    return PanelModel.folderMeta(folder, folderRescanning(folder))
  }

  function folderState(folder) {
    if (syncthing && !syncthing.online) return "UNKNOWN"
    return PanelModel.folderState(folder,
      syncthing ? syncthing.recentlyLinkedFolderId : "",
      folderHasActivity(folder), folderRescanning(folder))
  }

  function folderStateColor(folder) {
    var state = folderState(folder)
    if (state === "UNLINKED") return warning
    if (state === "SCANNING") return warning
    if (state === "SCAN+SYNC") return warning
    if (state === "SYNCING") return warning
    if (state === "UNKNOWN") return warning
    if (state === "ERROR") return urgent
    return success
  }

  function folderHasActivity(folder) {
    return folder && syncthing && visibleSyncActivity !== ""
      && syncthing.syncActivityFolderId === folder.id
  }

  function folderRescanning(folder) {
    if (!folder || !syncthing || folder.paused) return false
    if (!syncthing.folderMutationBusy) return false
    if (syncthing.folderMutationAction === "rescan"
        && syncthing.folderMutationId === String(folder.id || ""))
      return true
    if (syncthing.folderMutationAction !== "rescan-all") return false
    if (folder.scanning) return true
    return scanningFolderCount === 0
  }

  function currentFolder() {
    return currentFolderRow
  }

  function folderById(folderId) {
    return PanelModel.folderById(folderRows, folderId)
  }

  function ensureCurrentFolder() {
    if (currentFolder()) return
    currentFolderId = folderRows.length > 0 ? folderRows[0].id : ""
  }

  function cycleCurrentFolder(offset) {
    if (folderRows.length < 2 || offset === 0) return
    var current = currentFolder()
    var index = current ? folderRows.indexOf(current) : 0
    index = (index + (offset > 0 ? 1 : -1) + folderRows.length)
      % folderRows.length
    currentFolderId = folderRows[index].id
  }

  function folderOptions() {
    return PanelModel.folderOptions(folderRows, homePath)
  }

  function deviceName(deviceId) {
    var devices = syncthing && syncthing.devices ? syncthing.devices : []
    return PanelModel.deviceName(devices, deviceId)
  }

  function deviceOptions() {
    return PanelModel.deviceOptions(syncthing)
  }

  function remoteDeviceRows() {
    return PanelModel.remoteDeviceRows(syncthing)
  }

  function pendingDeviceRows() {
    return PanelModel.pendingDeviceRows(syncthing)
  }

  function nearbyDeviceOptions() {
    return PanelModel.nearbyDeviceOptions(syncthing)
  }

  function requestPendingDeviceDismiss(device) {
    if (!device || !syncthing || syncthing.folderMutationBusy) return
    deviceConfirmId = String(device.id || "")
    deviceConfirmName = String(device.name || "")
      || PanelModel.shortDeviceId(device.id)
    deviceConfirmAction = "dismiss"
  }

  function requestDeviceRemoval(device) {
    if (!device || !syncthing || syncthing.folderMutationBusy) return
    deviceConfirmId = String(device.id || "")
    deviceConfirmName = String(device.name || "")
      || PanelModel.shortDeviceId(device.id)
    deviceConfirmAction = "remove"
  }

  function confirmDeviceAction() {
    var action = deviceConfirmAction
    var id = deviceConfirmId
    var name = deviceConfirmName
    cancelDeviceAction()
    if (!syncthing) return
    if (action === "dismiss") syncthing.dismissPendingDevice(id, name)
    else if (action === "remove") syncthing.removeDevice(id, name)
  }

  function cancelDeviceAction() {
    deviceConfirmAction = ""
    deviceConfirmId = ""
    deviceConfirmName = ""
  }

  function pendingOfferOptions() {
    return PanelModel.pendingOfferOptions(syncthing)
  }

  function pendingFolderOptions() {
    var options = [{ value: "", label: "Create a new folder identity" }]
    for (var i = 0; i < pendingOfferRows.length; i++) {
      options.push({
        value: pendingOfferRows[i].value,
        label: "Accept " + pendingOfferRows[i].label
      })
    }
    return options
  }

  function ensurePendingOfferSelection() {
    for (var i = 0; i < pendingOfferRows.length; i++) {
      if (pendingOfferRows[i].value === selectedPendingOffer) return
    }
    selectedPendingOffer = pendingOfferRows.length > 0
      ? pendingOfferRows[0].value : ""
  }

  function encryptedPendingOfferCount() {
    return PanelModel.encryptedPendingOfferCount(syncthing)
  }

  function pathLabel(path) {
    return PanelModel.pathLabel(path)
  }

  function pathParentName(path) {
    return PanelModel.pathParentName(path, homePath)
  }

  function localPathFromUrl(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = value.slice(7)
    return decodeURIComponent(value)
  }

  function openAddFolder() {
    if (!syncthing || !syncthing.online || syncthing.folderMutationBusy) return
    syncthing.clearFolderMutationMessage()
    addOpen = true
    addIdEdited = false
    addLabelFromOffer = false
    addSubmissionPending = false
    folderShareOpen = false
    popup.resetAddForm()
    syncthing.requestFolderIdSuggestion()
    Qt.callLater(function() { popup.focusAddPath() })
  }

  function closeAddFolder() {
    if (syncthing && syncthing.folderMutationBusy
        && syncthing.folderMutationAction === "add") return
    addOpen = false
    folderShareOpen = false
    addSubmissionPending = false
    popup.focusPanel()
  }

  function resetTransientState() {
    moreOpen = false
    settingsMenuOpen = false
    removalConfirmOpen = false
    addOpen = false
    addIdEdited = false
    addLabelFromOffer = false
    addSubmissionPending = false
    cancelFolderAction()
    cancelDeviceAction()
    folderPickerError = ""
    popup.closeTransientPopups()
  }

  function applyPendingFolder(value) {
    var selected = String(value || "")
    popup.selectedDeviceIds = []
    if (!selected) {
      addIdEdited = false
      popup.addIdText = ""
      if (addLabelFromOffer) popup.addLabelText = ""
      addLabelFromOffer = false
      if (syncthing) syncthing.requestFolderIdSuggestion()
      return
    }
    var choice
    try {
      choice = JSON.parse(selected)
    } catch (error) {
      return
    }
    if (!(choice instanceof Array) || choice.length !== 2) return
    var id = String(choice[0] || "")
    var deviceId = String(choice[1] || "")
    var pending = syncthing && syncthing.pendingFolders
      ? syncthing.pendingFolders[id] || ({}) : ({})
    var offeredBy = pending.offeredBy || ({})
    var offer = offeredBy[deviceId] || ({})
    addIdEdited = true
    popup.addIdText = id
    popup.addLabelText = String(offer.label || id)
    addLabelFromOffer = true
    popup.selectedDeviceIds = deviceId ? [deviceId] : []
  }

  function acceptPendingFolderOffer(value) {
    var selected = String(value || "")
    if (!selected) return
    openAddFolder()
    if (!addOpen) return
    popup.pendingFolderValue = selected
    applyPendingFolder(selected)
    popup.scrollToMore()
    Qt.callLater(function() { popup.focusAddPath() })
  }

  function selectedPendingDeviceId() {
    var value = String(popup.pendingFolderValue || "")
    if (!value) return ""
    try {
      var choice = JSON.parse(value)
      if (!(choice instanceof Array) || choice.length !== 2) return ""
      var deviceId = String(choice[1] || "")
      return popup.selectedDeviceIds.indexOf(deviceId) >= 0 ? deviceId : ""
    } catch (error) {
      return ""
    }
  }

  function submitAddFolder() {
    if (!syncthing || syncthing.folderMutationBusy) return
    var label = String(popup.addLabelText || "").trim()
    if (!label) label = pathLabel(popup.addPathText)
    currentFolderId = String(popup.addIdText || "").trim()
    addSubmissionPending = syncthing.addFolder(
      resolveFolderPath(String(popup.addPathText || "").trim()),
      label,
      popup.addIdText,
      popup.selectedDeviceIds,
      selectedPendingDeviceId())
  }

  function requestForget(folder) {
    if (!folder || !folder.paused || !syncthing
        || syncthing.folderMutationBusy) return
    currentFolderId = folder.id
    folderConfirmId = folder.id
    folderConfirmAction = "forget"
  }

  function requestFolderLinkChange(folder, linked) {
    if (!folder || !syncthing || syncthing.folderMutationBusy) return
    currentFolderId = folder.id
    folderConfirmId = folder.id
    folderConfirmAction = linked ? "link" : "unlink"
  }

  function confirmFolderAction() {
    var action = folderConfirmAction
    var id = folderConfirmId
    var creation = folderCreationArgs
    cancelFolderAction()
    if (!syncthing) return
    if (action === "create" && creation) {
      addSubmissionPending = syncthing.addFolder(creation.path,
        creation.label, creation.folderId, creation.deviceIds,
        creation.pendingDeviceId, true)
    } else if (action === "forget") syncthing.forgetFolder(id)
    else syncthing.setFolderLinked(id, action === "link")
  }

  function cancelFolderAction() {
    folderConfirmAction = ""
    folderConfirmId = ""
    folderCreationArgs = null
  }

  function openWebUi() {
    if (syncthing && syncthing.online) syncthing.openWebUi()
  }

  function openSettingsMenu() {
    closeTransientViews()
    settingsSelectedIndex = 0
    settingsMenuOpen = true
    Qt.callLater(function() { popup.focusPanel() })
  }

  function chooseSettingsPort(index) {
    if (!syncthing) return
    if (index === 0) syncthing.autoPortSettings()
    else if (index === 1) syncthing.manualPortSettings()
    else syncthing.cancelSettingsMigration()
  }

  function closeSettingsMenu() {
    removalConfirmOpen = false
    settingsMenuOpen = false
    popup.focusPanel()
  }

  function closeTransientViews() {
    moreOpen = false
    addOpen = false
    cancelFolderAction()
    popup.closeTransientPopups()
  }

  function moveSettingsSelection(offset) {
    settingsSelectedIndex = (settingsSelectedIndex
      + (offset > 0 ? 1 : 2)) % 3
  }

  function activateSettingsSelection() {
    if (settingsSelectedIndex === 0) {
      settingsMenuOpen = false
      if (syncthing) syncthing.openSettings()
    } else if (settingsSelectedIndex === 1) {
      removalConfirmOpen = true
    } else closeSettingsMenu()
  }

  function requestSelfRemoval(deletePluginSettings) {
    if (!syncthing) return
    syncthing.requestSelfRemoval(deletePluginSettings)
  }

  function openFolder(folder) {
    var path = resolveFolderPath(folder ? folder.path : "")
    if (!path) return
    Quickshell.execDetached(["uwsm-app", "--", "xdg-open", path])
  }

  function browseForFolder() {
    if (folderPickerProcess.running) return
    folderPickerOutput = ""
    folderPickerError = ""
    folderPickerProcess.command = ["bash", folderPickerScript]
    preserveStateForFolderPicker = true
    close()
    folderPickerProcess.running = true
  }

  function resolveFolderPath(value) {
    var path = String(value || "")
    if (path === "~") return homePath
    if (path.indexOf("~/") === 0) return homePath + path.slice(1)
    if (path.charAt(0) === "/" || !homePath) return path
    return homePath + "/" + path
  }

  function toggleSyncing() {
    if (syncthing && syncthing.canControlService
        && !syncthing.serviceActionRunning) syncthing.toggleService()
  }

  function installationAction() {
    if (syncthing && syncthing.installationState === "missing") {
      syncthing.installSyncthing()
    }
  }

  function openSyncthingPackageDocumentation() {
    Qt.openUrlExternally("https://omarchy.org/manual/other-packages/")
  }

  onSyncthingChanged: configureService()
  onSettingsChanged: configureService()
  onFolderRowsChanged: ensureCurrentFolder()
  onPendingOfferRowsChanged: ensurePendingOfferSelection()
  onVisibleNoticeChanged: {
    if (visibleNotice !== "") {
      showNotice(visibleNotice, visibleNoticeDurationMs)
    } else if (displayedNotice !== "") {
      noticeDisplayTimer.stop()
      noticeShown = false
      noticeFadeTimer.restart()
    }
  }
  onOpenedChanged: {
    if (opened) {
      if (syncthing) {
        syncthing.recheckSettings()
        syncthing.refresh()
      }
      ensureCurrentFolder()
      popup.scrollToTop()
      Qt.callLater(function() { popup.focusPanel() })
    } else if (!preserveStateForFolderPicker) {
      if (settingsMigrationOpen) syncthing.cancelSettingsMigration()
      resetTransientState()
    }
  }
  Component.onCompleted: configureService()

  Timer {
    id: noticeDisplayTimer
    interval: UiConstants.NOTICE_VISIBLE_MS
    repeat: false
    onTriggered: {
      root.noticeShown = false
      noticeFadeTimer.restart()
    }
  }

  Timer {
    id: noticeFadeTimer
    interval: UiConstants.NOTICE_FADE_MS
    repeat: false
    onTriggered: {
      if (root.noticeShown) return
      var expired = root.displayedNotice
      root.displayedNotice = ""
      if (root.syncthing
          && root.syncthing.folderMutationNotice === expired) {
        root.syncthing.clearFolderMutationNotice()
      }
      if (root.syncthing
          && root.syncthing.settingsNotice === expired) {
        root.syncthing.clearSettingsNotice()
      }
    }
  }

  Connections {
    target: root.syncthing

    function onFolderDirectoryRequired(args) {
      root.addSubmissionPending = false
      if (!root.addOpen || !root.opened) return
      root.folderCreationArgs = args
      root.folderConfirmAction = "create"
      popup.closeTransientPopups()
      popup.focusPanel()
    }

    function onFolderIdSuggestionChanged() {
      if (root.addOpen && !root.addIdEdited
          && popup.pendingFolderValue === "") {
        popup.addIdText = root.syncthing.folderIdSuggestion
      }
    }

    function onFolderMutationNoticeChanged() {
      if (root.addSubmissionPending
          && root.syncthing.folderMutationNotice !== "") {
        root.addOpen = false
        root.addSubmissionPending = false
        popup.focusPanel()
      }
    }

    function onFolderMutationErrorChanged() {
      if (root.syncthing.folderMutationError !== "") {
        root.addSubmissionPending = false
      }
    }

  }

  Process {
    id: folderPickerProcess
    command: []

    stdout: StdioCollector {
      id: folderPickerStdout
      waitForEnd: true
      onStreamFinished: root.folderPickerOutput = text
    }

    onExited: function(exitCode) {
      var selected = String(root.folderPickerOutput
        || folderPickerStdout.text || "").trim()
      if (exitCode === 0 && selected) {
        var path = root.localPathFromUrl(selected)
        popup.addPathText = path
        if (!popup.addLabelText) popup.addLabelText = root.pathLabel(path)
      } else if (exitCode !== 0) {
        root.folderPickerError = "Folder chooser failed; enter the path manually."
      }
      Qt.callLater(function() {
        root.preserveStateForFolderPicker = false
        root.open()
        if (root.addOpen) {
          Qt.callLater(function() { popup.focusAddPath() })
        }
      })
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Timer {
    id: barTooltipTimer
    interval: UiConstants.TOOLTIP_DELAY_MS
    onTriggered: root.showBarTooltip()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        opacity: root.syncthing && root.syncthing.online ? 1.0 : 0.55

        // Keep the effect warm under the brand icon for reliable live switches.
        MonoIcon {
          anchors.fill: parent
          source: root.themedIconSource
          tint: button.foreground
        }

        Image {
          anchors.fill: parent
          source: root.syncthingIconSource
          sourceSize.width: width
          sourceSize.height: height
          fillMode: Image.PreserveAspectFit
          smooth: true
          visible: !root.themedIcon
        }
      }
    }
    active: root.hasProblems
    tooltipText: ""
    onTooltipHoveredChanged: {
      if (tooltipHovered) barTooltipTimer.restart()
      else {
        barTooltipTimer.stop()
        if (root.bar) root.bar.hideTooltip(button)
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton && root.syncthing) root.syncthing.refresh()
      else root.toggle()
    }
  }

  SyncthingPanelPopup {
    id: popup
    anchorItem: button
    controller: root
    owner: root
    bar: root.bar
    open: root.opened
  }

}
