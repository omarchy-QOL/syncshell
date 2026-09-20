import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property var controller
  property var syncthing
  property color foreground: Color.foreground
  property color urgent: Color.urgent
  required property color warning
  property string fontFamily: Style.font.family
  property var draftDeviceIds: []
  property bool submitting: false
  readonly property var folder: controller ? controller.currentFolderRow : null
  readonly property bool popupOpen: devicePicker.popupOpen

  function resetDraft() {
    var selected = []
    var members = folder && folder.devices ? folder.devices : []
    for (var i = 0; i < members.length; i++) {
      var id = String((members[i] || {}).deviceID || "")
      if (id && id !== syncthing.localDeviceId) selected.push(id)
    }
    draftDeviceIds = selected
  }

  function closePopups() { devicePicker.close() }

  onVisibleChanged: if (visible) resetDraft()
  onFolderChanged: if (visible) resetDraft()

  width: parent ? parent.width : implicitWidth
  implicitHeight: content.implicitHeight + Style.space(8)
  color: "transparent"
  borderSpec: Border.controlSpec("normal", foreground, Color.accent)
  radius: Style.cornerRadius

  Connections {
    target: root.syncthing
    function onFolderMutationNoticeChanged() {
      if (!root.submitting || !root.syncthing.folderMutationNotice) return
      root.submitting = false
      root.controller.folderShareOpen = false
    }
    function onFolderMutationErrorChanged() {
      if (root.syncthing.folderMutationError) root.submitting = false
    }
  }

  Column {
    id: content
    anchors.fill: parent
    anchors.margins: Style.space(8)
    anchors.topMargin: 0
    spacing: Style.space(6)

    InlineFormHeader {
      title: "SHARE " + String(root.folder && root.folder.label || "FOLDER")
      foreground: root.foreground
      cancelColor: root.urgent
      fontFamily: root.fontFamily
      cancelEnabled: !root.submitting
      onCanceled: root.controller.folderShareOpen = false
    }

    Text {
      visible: root.controller.deviceOptions().length === 0
      width: parent.width
      text: "No remote devices available. Add a remote device below."
      textFormat: Text.PlainText
      color: root.warning
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    SyncshellMultiSelect {
      id: devicePicker
      visible: options.length > 0
      width: parent.width
      label: "Share with devices"
      values: root.draftDeviceIds
      options: root.controller.deviceOptions()
      noSelectionText: "Local only"
      placeholderText: "Find a device..."
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(values) { root.draftDeviceIds = values }
    }

    Button {
      visible: root.controller.deviceOptions().length > 0
      width: parent.width
      text: root.submitting ? "SAVING..." : "SAVE SHARING"
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      enabled: root.syncthing && root.syncthing.online && !root.submitting
        && !root.syncthing.folderMutationBusy && root.folder
      onClicked: {
        root.submitting = root.syncthing.setFolderSharing(
          root.folder.id, root.draftDeviceIds)
      }
    }
  }
}
