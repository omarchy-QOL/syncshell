import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property var controller
  property var syncthing
  property var device
  property bool submitting: false
  property string nameText: ""
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.5)
  property color urgent: Color.urgent
  property string fontFamily: Style.font.family

  signal canceled()
  signal submissionStarted(bool started)

  function reset() {
    nameText = String(device && device.name || "")
  }

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
      title: "ACCEPT REMOTE DEVICE REQUEST"
      foreground: root.foreground
      cancelColor: root.urgent
      fontFamily: root.fontFamily
      cancelEnabled: !root.submitting
      onCanceled: root.canceled()
    }

    RowLayout {
      width: parent.width
      spacing: Style.space(6)

      Text {
        text: "Name"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      TextField {
        Layout.fillWidth: true
        text: root.nameText
        placeholderText: "Optional name"
        foreground: root.foreground
        horizontalAlignment: TextInput.AlignRight
        onTextEdited: root.nameText = text
      }
    }

    RowLayout {
      width: parent.width
      spacing: Style.space(6)

      Text {
        text: "Observed address"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        Layout.fillWidth: true
        text: String(root.device && root.device.address || "")
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
      }
    }

    RowLayout {
      width: parent.width
      spacing: Style.space(6)

      Text {
        text: "Device ID"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        Layout.fillWidth: true
        text: String(root.device && root.device.id || "")
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideMiddle
      }

      IdCopyButton {
        Layout.preferredWidth: Style.space(18)
        Layout.preferredHeight: Style.space(18)
        value: String(root.device && root.device.id || "")
        notice: "Device ID copied"
        helpText: "Copy device ID"
        controller: root.controller
        foreground: root.foreground
        fontFamily: root.fontFamily
        iconSize: Math.max(Style.space(7), Style.font.caption - 3)
      }
    }

    Button {
      width: parent.width
      text: root.submitting ? "ACCEPTING..."
        : "ACCEPT REMOTE DEVICE CONNECTION"
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      enabled: root.device && root.syncthing && !root.submitting
        && !root.syncthing.folderMutationBusy
      onClicked: root.submissionStarted(root.syncthing.addDevice(
        root.device.id, root.nameText))
    }
  }
}
