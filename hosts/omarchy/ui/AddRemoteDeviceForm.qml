import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property var controller
  property var syncthing
  property bool submitting: false
  property string sourceId: ""
  property string deviceId: ""
  property string deviceName: ""
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.5)
  property color urgent: Color.urgent
  required property color warning
  property string fontFamily: Style.font.family
  readonly property bool popupOpen: sourceSelector.popupOpen

  signal canceled()
  signal submissionStarted(bool started)

  function reset() {
    sourceId = ""
    deviceId = ""
    deviceName = ""
  }

  function closePopups() { sourceSelector.close() }

  function validDeviceId(value) {
    var id = String(value || "").trim().toUpperCase()
    if (!/^[A-Z2-7]{7}(-[A-Z2-7]{7}){7}$/.test(id)) return false
    if (id === String(syncthing && syncthing.localDeviceId || "")) return false
    var rows = controller.remoteDeviceRows()
    for (var i = 0; i < rows.length; i++) {
      if (String(rows[i].id || "") === id) return false
    }
    return true
  }

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
      title: "ADD REMOTE DEVICE"
      foreground: root.foreground
      cancelColor: root.urgent
      fontFamily: root.fontFamily
      cancelEnabled: !root.submitting
      onCanceled: root.canceled()
    }

    SyncshellDropdown {
      id: sourceSelector
      width: parent.width
      label: "Device source"
      value: root.sourceId
      options: root.controller.nearbyDeviceOptions()
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(value) {
        root.sourceId = value
        root.deviceId = value
      }
    }

    Text {
      text: "Device ID"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    TextField {
      width: parent.width
      text: root.deviceId
      enabled: root.sourceId === ""
      placeholderText: "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-..."
      foreground: root.foreground
      onTextEdited: root.deviceId = text.toUpperCase()
    }

    Text {
      visible: root.controller.nearbyDeviceOptions().length === 1
      width: parent.width
      text: "  No nearby device found. Use the device ID."
      textFormat: Text.PlainText
      color: root.warning
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Text {
      text: "Remote Device Name"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    TextField {
      width: parent.width
      text: root.deviceName
      placeholderText: "Optional; adopted from the remote when empty"
      foreground: root.foreground
      onTextEdited: root.deviceName = text
    }

    Button {
      width: parent.width
      text: root.submitting ? "ADDING..." : "ADD REMOTE DEVICE"
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      enabled: root.validDeviceId(root.deviceId) && root.syncthing
        && !root.submitting && !root.syncthing.folderMutationBusy
      onClicked: root.submissionStarted(root.syncthing.addDevice(
        root.deviceId, root.deviceName))
    }
  }
}
