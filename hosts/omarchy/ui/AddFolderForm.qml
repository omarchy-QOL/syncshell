import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property var controller
  property var syncthing
  property bool folderPickerRunning: false
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.5)
  property color urgent: Color.urgent
  required property color warning
  property string fontFamily: Style.font.family
  property alias pathText: addPathField.text
  property alias labelText: addLabelField.text
  property alias idText: addIdField.text
  property alias selectedDeviceIds: devicePicker.values
  property alias pendingFolderValue: pendingFolderPicker.value

  function reset() {
    addPathField.text = ""
    addLabelField.text = ""
    addIdField.text = ""
    devicePicker.values = []
    pendingFolderPicker.value = ""
    devicePicker.close()
  }

  function closePopups() {
    if (devicePicker.popupOpen) devicePicker.close()
  }

  function focusPath() {
    addPathField.forceActiveFocus()
  }

  width: parent ? parent.width : implicitWidth
  implicitHeight: addColumn.implicitHeight + Style.space(8)
  color: "transparent"
  borderSpec: Border.controlSpec("normal", foreground, Color.accent)
  radius: Style.cornerRadius
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      controller.closeAddFolder()
      event.accepted = true
    }
  }

  Column {
    id: addColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(8)
    anchors.topMargin: 0
    spacing: Style.space(6)

    InlineFormHeader {
      title: "ADD FOLDER"
      foreground: root.foreground
      cancelColor: root.urgent
      fontFamily: root.fontFamily
      cancelEnabled: !root.syncthing || !root.syncthing.folderMutationBusy
      onCanceled: root.controller.closeAddFolder()
    }

    SyncshellDropdown {
      id: pendingFolderPicker
      visible: options.length > 1
      width: parent.width
      showLabel: false
      value: ""
      options: root.controller.pendingFolderOptions()
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(value) { root.controller.applyPendingFolder(value) }
    }

    Text {
      readonly property int encryptedCount:
        root.controller.encryptedPendingOfferCount()
      visible: encryptedCount > 0
      width: parent.width
      text: encryptedCount + " encrypted folder offer"
        + (encryptedCount === 1 ? " requires" : "s require")
        + " the Syncthing Web UI."
      textFormat: Text.PlainText
      color: root.warning
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Text {
      text: "Local directory"
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    RowLayout {
      width: parent.width
      spacing: Style.space(6)

      TextField {
        id: addPathField
        Layout.fillWidth: true
        enabled: !root.syncthing || !root.syncthing.folderMutationBusy
        placeholderText: "/path/to/existing/folder"
        foreground: root.foreground
      }

      TooltipButton {
        text: "BROWSE"
        Layout.preferredHeight: addPathField.implicitHeight
        helpText: "Choose an existing local directory"
        bordered: true
        foreground: root.foreground
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        enabled: (!root.syncthing || !root.syncthing.folderMutationBusy)
          && !root.folderPickerRunning
        onClicked: root.controller.browseForFolder()
      }
    }

    Text {
      text: "Label"
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    TextField {
      id: addLabelField
      width: parent.width
      enabled: !root.syncthing || !root.syncthing.folderMutationBusy
      placeholderText: "Derived from the directory name when empty"
      foreground: root.foreground
      onTextEdited: root.controller.addLabelFromOffer = false
    }

    Text {
      text: "Folder ID"
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    RowLayout {
      width: parent.width
      spacing: Style.space(6)

      TextField {
        id: addIdField
        Layout.fillWidth: true
        enabled: !root.syncthing || !root.syncthing.folderMutationBusy
        placeholderText: root.syncthing
          && root.syncthing.folderPreparationBusy
          ? "Generating..." : "Required folder identity"
        foreground: root.foreground
        onTextEdited: root.controller.addIdEdited = true
        onAccepted: root.controller.submitAddFolder()
      }

      TooltipButton {
        text: "NEW ID"
        Layout.preferredHeight: addIdField.implicitHeight
        helpText: "Generate a new Syncthing folder ID"
        bordered: true
        foreground: root.foreground
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        enabled: root.syncthing && !root.syncthing.folderPreparationBusy
          && !root.syncthing.folderMutationBusy
        onClicked: {
          root.controller.addIdEdited = false
          addIdField.text = ""
          pendingFolderPicker.value = ""
          root.syncthing.requestFolderIdSuggestion()
        }
      }
    }

    Text {
      width: parent.width
      text: "Reuse the exact ID to rejoin an existing remote folder. "
        + "A new ID creates a different folder identity."
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    SyncshellMultiSelect {
      id: devicePicker
      width: parent.width
      label: "Share with devices"
      values: []
      options: root.controller.deviceOptions()
      noSelectionText: "Local only"
      placeholderText: "Find a device..."
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Text {
      width: parent.width
      text: devicePicker.values.length === 0
        ? "Local only: not shared with other devices."
        : "Selected devices receive a share offer and may need to accept it."
      textFormat: Text.PlainText
      color: devicePicker.values.length === 0 ? root.warning : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.NoWrap
      elide: Text.ElideRight
    }

    Text {
      visible: root.syncthing
        && root.syncthing.folderPreparationError !== ""
      width: parent.width
      text: root.syncthing ? root.syncthing.folderPreparationError : ""
      textFormat: Text.PlainText
      color: root.urgent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Button {
      width: parent.width
      text: root.syncthing && root.syncthing.folderMutationBusy
        && root.syncthing.folderMutationAction === "add"
        ? "ADDING..." : "ADD FOLDER"
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      enabled: root.syncthing && root.syncthing.online
        && !root.syncthing.folderMutationBusy
        && String(addPathField.text || "").trim() !== ""
        && String(addIdField.text || "").trim() !== ""
      onClicked: root.controller.submitAddFolder()
    }
  }
}
