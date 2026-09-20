import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Column {
  id: root

  property var controller
  property var syncthing
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.5)
  property color urgent: Color.urgent
  property color warning: "#ebcb8b"
  property color success: "#a3be8c"
  property string fontFamily: Style.font.family

  property string selectedDeviceId: ""
  property string selectedPendingId: ""
  property bool addOpen: false
  property bool acceptOpen: false
  property bool foldersOpen: false
  property bool submitting: false

  readonly property var remoteRows: controller.remoteDeviceRows()
  readonly property var pendingRows: controller.pendingDeviceRows()
  readonly property var selectedDevice: rowById(remoteRows, selectedDeviceId)
  readonly property var selectedPending: rowById(pendingRows, selectedPendingId)
  readonly property bool popupOpen: deviceSelector.popupOpen
    || pendingSelector.popupOpen || addForm.popupOpen
    || foldersForm.popupOpen

  function rowById(rows, id) {
    for (var i = 0; i < rows.length; i++) {
      if (String(rows[i].id || "") === String(id || "")) return rows[i]
    }
    return null
  }

  function ensureSelections() {
    if (!selectedDevice && remoteRows.length > 0)
      selectedDeviceId = remoteRows[0].id
    if (!selectedPending && pendingRows.length > 0)
      selectedPendingId = pendingRows[0].id
  }

  function deviceOptions() {
    var options = []
    for (var i = 0; i < remoteRows.length; i++)
      options.push({ value: remoteRows[i].id, label: remoteRows[i].label })
    return options
  }

  function pendingOptions() {
    var options = []
    for (var i = 0; i < pendingRows.length; i++)
      options.push({ value: pendingRows[i].id, label: pendingRows[i].label })
    return options
  }

  function openAdd() {
    addOpen = true
    acceptOpen = false
    foldersOpen = false
    if (syncthing) syncthing.refresh()
    Qt.callLater(function() { controller.scrollToMore() })
  }

  function openAccept() {
    if (!selectedPending) return
    acceptOpen = true
    addOpen = false
    foldersOpen = false
    Qt.callLater(function() { controller.scrollToMore() })
  }

  function openFolders() {
    if (!selectedDevice) return
    foldersOpen = true
    addOpen = false
    acceptOpen = false
    Qt.callLater(function() { controller.scrollToMore() })
  }

  function closePopups() {
    deviceSelector.close()
    pendingSelector.close()
    addForm.closePopups()
    foldersForm.closePopups()
  }

  onRemoteRowsChanged: ensureSelections()
  onPendingRowsChanged: ensureSelections()
  Component.onCompleted: ensureSelections()

  Connections {
    target: root.syncthing
    function onFolderMutationNoticeChanged() {
      if (!root.submitting || !root.syncthing.folderMutationNotice) return
      root.submitting = false
      root.addOpen = false
      root.acceptOpen = false
      root.foldersOpen = false
    }
    function onFolderMutationErrorChanged() {
      if (root.syncthing.folderMutationError) root.submitting = false
    }
  }

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(8)

  Column {
    visible: root.pendingRows.length > 0
    width: parent.width
    spacing: Style.space(6)

    PanelSectionHeader {
      text: "PENDING DEVICE REQUESTS"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    RowLayout {
      width: parent.width
      spacing: Style.space(6)

      SyncshellDropdown {
        id: pendingSelector
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(28)
        showLabel: false
        rowHeight: Style.space(28)
        value: root.selectedPendingId
        options: root.pendingOptions()
        interactive: options.length > 1
        helpText: root.selectedPending
          ? "Remote device " + (root.selectedPending.name
            || root.selectedPending.shortId) + " attempted to connect." : ""
        foreground: root.foreground
        fontFamily: root.fontFamily
        onChanged: function(value) { root.selectedPendingId = value }
      }

      TooltipButton {
        iconText: "\uf00c"
        Layout.preferredHeight: Style.space(28)
        helpText: "Accept remote device connection"
        bordered: true
        foreground: root.success
        fontFamily: root.fontFamily
        iconSize: Style.font.icon
        enabled: root.selectedPending && !root.syncthing.folderMutationBusy
        onClicked: root.openAccept()
      }

      TooltipButton {
        iconText: "\uf00d"
        Layout.preferredHeight: Style.space(28)
        helpText: "Dismiss incoming device request"
        bordered: true
        foreground: root.urgent
        fontFamily: root.fontFamily
        iconSize: Style.font.icon
        enabled: root.selectedPending && !root.syncthing.folderMutationBusy
        onClicked: root.controller.requestPendingDeviceDismiss(
          root.selectedPending)
      }
    }
  }

  AcceptRemoteDeviceForm {
    id: acceptForm
    visible: root.acceptOpen && root.selectedPending
    controller: root.controller
    syncthing: root.syncthing
    device: root.selectedPending
    submitting: root.submitting
    foreground: root.foreground
    dim: root.dim
    urgent: root.urgent
    fontFamily: root.fontFamily
    onCanceled: root.acceptOpen = false
    onSubmissionStarted: function(started) { root.submitting = started }
  }

  PanelSectionHeader {
    text: "REMOTE DEVICES"
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  RowLayout {
    width: parent.width
    spacing: Style.space(6)

    SyncshellDropdown {
      id: deviceSelector
      visible: root.remoteRows.length > 0
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(28)
      showLabel: false
      rowHeight: Style.space(28)
      value: root.selectedDeviceId
      options: root.deviceOptions()
      statusVisible: true
      statusColor: root.selectedDevice && root.selectedDevice.connected
        ? root.success : root.urgent
      statusHelpText: root.selectedDevice && root.selectedDevice.connected
        ? "Device is connected" : "Device is disconnected"
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(value) { root.selectedDeviceId = value }
    }

    Text {
      visible: root.remoteRows.length === 0
      Layout.fillWidth: true
      text: "No remote devices configured."
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    TooltipButton {
      visible: root.remoteRows.length > 0
      text: "FOLDERS"
      Layout.preferredHeight: Style.space(28)
      helpText: "View folders shared with\nthe selected device"
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      fontSize: Style.font.caption
      enabled: root.selectedDevice && !root.syncthing.folderMutationBusy
      onClicked: root.openFolders()
    }

    TooltipButton {
      iconText: "\uf067"
      Layout.preferredHeight: Style.space(28)
      helpText: "Add device"
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      iconSize: Style.font.icon
      enabled: root.syncthing && root.syncthing.online
        && !root.syncthing.folderMutationBusy
      onClicked: {
        if (root.addOpen) root.addOpen = false
        else root.openAdd()
      }
    }
  }

  Text {
    visible: root.selectedDevice && root.selectedDevice.folderIds.length === 0
      && !root.foldersOpen
    width: parent.width
    text: root.selectedDevice
      ? "No folders are shared with " + root.selectedDevice.name
        + ". Select a folder above and use Share Folder." : ""
    textFormat: Text.PlainText
    color: root.warning
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  DeviceFoldersForm {
    id: foldersForm
    visible: root.foldersOpen && root.selectedDevice
    controller: root.controller
    syncthing: root.syncthing
    device: root.selectedDevice
    submitting: root.submitting
    foreground: root.foreground
    urgent: root.urgent
    warning: root.warning
    fontFamily: root.fontFamily
    onCanceled: root.foldersOpen = false
    onSubmissionStarted: function(started) { root.submitting = started }
  }

  AddRemoteDeviceForm {
    id: addForm
    visible: root.addOpen
    controller: root.controller
    syncthing: root.syncthing
    submitting: root.submitting
    foreground: root.foreground
    dim: root.dim
    urgent: root.urgent
    warning: root.warning
    fontFamily: root.fontFamily
    onCanceled: root.addOpen = false
    onSubmissionStarted: function(started) { root.submitting = started }
  }
}
