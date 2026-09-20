import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property var controller
  property var syncthing
  property var device
  property bool submitting: false
  property var draftFolderIds: []
  property color foreground: Color.foreground
  property color urgent: Color.urgent
  required property color warning
  property string fontFamily: Style.font.family
  readonly property bool popupOpen: folderPicker.popupOpen

  signal canceled()
  signal submissionStarted(bool started)

  function folderOptions() {
    var options = []
    var ids = device ? device.folderIds || [] : []
    for (var i = 0; i < ids.length; i++) {
      var folder = controller.folderById(ids[i])
      options.push({
        value: ids[i],
        label: String(folder && folder.label || ids[i])
      })
    }
    return options
  }

  function reset() {
    draftFolderIds = device ? (device.folderIds || []).slice() : []
  }

  function removedFolderIds() {
    var removed = []
    var original = device ? device.folderIds || [] : []
    for (var i = 0; i < original.length; i++) {
      if (draftFolderIds.indexOf(original[i]) < 0) removed.push(original[i])
    }
    return removed
  }

  function closePopups() { folderPicker.close() }

  onDeviceChanged: reset()
  onVisibleChanged: if (visible) reset()

  width: parent ? parent.width : implicitWidth
  implicitHeight: content.implicitHeight + Style.space(8)
  color: "transparent"
  borderSpec: Border.controlSpec("normal", foreground, Color.accent)
  radius: Style.cornerRadius

  Column {
    id: content
    anchors.fill: parent
    anchors.margins: Style.space(8)
    anchors.topMargin: 0
    spacing: Style.space(6)

    InlineFormHeader {
      title: "SHARED WITH " + String(root.device
        && root.device.name || "DEVICE")
      foreground: root.foreground
      cancelColor: root.urgent
      fontFamily: root.fontFamily
      cancelEnabled: !root.submitting
      onCanceled: root.canceled()
    }

    Text {
      visible: root.folderOptions().length === 0
      width: parent.width
      text: "No folders are currently shared with this device."
      textFormat: Text.PlainText
      color: root.warning
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    SyncshellMultiSelect {
      id: folderPicker
      visible: options.length > 0
      width: parent.width
      label: "Existing shares"
      values: root.draftFolderIds
      options: root.folderOptions()
      noSelectionText: "No folders selected"
      placeholderText: "Find a folder..."
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(values) { root.draftFolderIds = values }
    }

    Text {
      visible: root.folderOptions().length > 0
      width: parent.width
      text: "  Use -button (share folder) to restore a folder."
      textFormat: Text.PlainText
      color: root.warning
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.NoWrap
      elide: Text.ElideRight
    }

    Button {
      visible: root.folderOptions().length > 0
      width: parent.width
      text: root.submitting ? "SAVING..." : "SAVE SHARING"
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      enabled: root.device && root.syncthing && !root.submitting
        && !root.syncthing.folderMutationBusy
        && root.removedFolderIds().length > 0
      onClicked: root.submissionStarted(
        root.syncthing.removeDeviceFolderShares(root.device.id,
          root.removedFolderIds(), root.device.name))
    }
  }
}
