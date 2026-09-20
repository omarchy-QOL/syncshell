pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "shared"

ShellRoot {
  id: root

  property bool popupOpen: false
  property bool moreOpen: false
  property bool addOpen: false
  property string pendingForgetId: ""
  property string pendingForgetLabel: ""
  property DeviceWorkflow deviceFlow: DeviceWorkflow { service: service }
  property string lastStatus: ""
  property string barPosition: "top"
  readonly property string pluginRoot: localPath(Qt.resolvedUrl("."))

  onPopupOpenChanged: {
    if (popupOpen) Qt.callLater(function() { background.forceActiveFocus() })
  }

  function localPath(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = value.slice(7)
    return decodeURIComponent(value)
  }

  function requestForget(folder) {
    pendingForgetId = String(folder.id || "")
    pendingForgetLabel = String(folder.label || folder.id || "folder")
  }

  function confirmForget() {
    if (pendingForgetId === "") return
    if (service.forgetFolder(pendingForgetId)) pendingForgetId = ""
  }

  function statusClass() {
    if (!service.online) return "offline"
    if (service.folderProblemCount > 0) return "error"
    if (service.syncingFolderCount > 0) return "syncing"
    return "idle"
  }

  function statusJson() {
    var details = ["Syncshell", service.summaryText]
    if (service.activityText !== "") details.push(service.activityText)
    if (service.lastError !== "") details.push(service.lastError)
    details.push(service.folderCount + " folders")
    return JSON.stringify({
      text: service.online ? "ST " + service.folderCount : "ST !",
      tooltip: details.join("\n"),
      "class": statusClass(),
      alt: statusClass()
    })
  }

  function publishStatus() {
    var value = statusJson()
    if (value === lastStatus) return
    statusFile.setText(value + "\n")
    lastStatus = value
  }

  AdapterService {
    id: service
    pluginRoot: root.pluginRoot
  }

  FileView {
    id: positionFile
    path: root.pluginRoot + "/position"
    watchChanges: true
    printErrors: false
    onLoaded: root.barPosition = text().trim() === "bottom" ? "bottom" : "top"
    onFileChanged: reload()
  }

  FileView {
    id: statusFile
    path: Quickshell.env("XDG_RUNTIME_DIR")
      + "/syncshell-waybar-status.json"
    printErrors: false
  }

  Timer {
    interval: 250
    repeat: true
    running: true
    onTriggered: root.publishStatus()
  }

  IpcHandler {
    target: "syncshell"

    function toggle(): void {
      root.popupOpen = !root.popupOpen
    }

    function hide(): void {
      root.popupOpen = false
    }

    function refresh(): void {
      service.refresh()
    }

    function openWebUi(): void {
      service.openWebUi()
    }
  }

  PanelWindow {
    id: popupWindow
    visible: root.popupOpen
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    color: "transparent"
    implicitWidth: 480
    implicitHeight: Math.min(700, popupContent.implicitHeight + 28)
    anchors.top: root.barPosition === "top"
    anchors.bottom: root.barPosition === "bottom"
    anchors.right: true
    margins.top: root.barPosition === "top" ? 42 : 0
    margins.bottom: root.barPosition === "bottom" ? 42 : 0
    margins.right: 10
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "syncshell-waybar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    mask: Region { item: background }

    HyprlandFocusGrab {
      active: root.popupOpen
      windows: [popupWindow]
      onCleared: root.popupOpen = false
    }

    Rectangle {
      id: background
      anchors.fill: parent
      color: "#1e1e2e"
      border.width: 1
      border.color: "#585b70"
      radius: 12
      focus: true
      Keys.onEscapePressed: {
        if (root.pendingForgetId !== "") root.pendingForgetId = ""
        else if (root.deviceFlow.view !== "") root.deviceFlow.close()
        else root.popupOpen = false
      }

      ColumnLayout {
        id: popupContent
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Label {
          Layout.fillWidth: true
          text: "Syncshell"
          color: "#cdd6f4"
          font.pixelSize: 20
          font.bold: true
        }

        Label {
          Layout.fillWidth: true
          text: service.summaryText
          color: "#bac2de"
        }

        Label {
          Layout.fillWidth: true
          visible: text.length > 0
          text: service.lastError || service.actionNotice
          color: service.lastError ? "#f38ba8" : "#a6e3a1"
          wrapMode: Text.Wrap
        }

        Label {
          visible: root.deviceFlow.view === ""
          Layout.fillWidth: true
          text: "FOLDERS"
          color: "#a6adc8"
          font.bold: true
        }

        Flickable {
          visible: root.deviceFlow.view === ""
          id: folderView
          Layout.fillWidth: true
          Layout.preferredHeight: service.folders.length === 0 ? 70
            : root.addOpen ? 130
            : Math.min(280, Math.max(90, folderColumn.implicitHeight))
          clip: true
          contentWidth: width
          contentHeight: folderColumn.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          ScrollBar.vertical: ScrollBar {}

          Column {
            id: folderColumn
            width: folderView.width
            spacing: 8

            Label {
              width: parent.width
              visible: service.folders.length === 0
              text: service.summaryText
              color: "#a6adc8"
              horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
              model: service.folders

              delegate: Rectangle {
                id: folderCard
                required property var modelData
                width: folderColumn.width
                height: folderDetails.implicitHeight + 16
                color: "#313244"
                radius: 8

                ColumnLayout {
                  id: folderDetails
                  anchors.fill: parent
                  anchors.margins: 8
                  spacing: 4

                  Label {
                    Layout.fillWidth: true
                    text: String(folderCard.modelData.label
                      || folderCard.modelData.id)
                    color: "#cdd6f4"
                    font.bold: true
                  }
                  Label {
                    Layout.fillWidth: true
                    text: String(folderCard.modelData.path || "")
                    color: "#a6adc8"
                    elide: Text.ElideMiddle
                  }
                  Label {
                    Layout.fillWidth: true
                    text: String(folderCard.modelData.status
                      && (folderCard.modelData.status.error
                        || folderCard.modelData.status.state) || "unknown")
                    color: folderCard.modelData.status
                      && folderCard.modelData.status.error
                      ? "#f38ba8" : "#bac2de"
                    elide: Text.ElideRight
                  }
                  RowLayout {
                    Button {
                      visible: root.moreOpen
                      text: folderCard.modelData.paused ? "Link" : "Unlink"
                      enabled: service.online && !service.busy
                      onClicked: service.setFolderPaused(
                        folderCard.modelData.id, !folderCard.modelData.paused)
                    }
                    Button {
                      visible: root.moreOpen
                        && service.shareableDevices().length > 0
                      text: "Share"
                      enabled: service.online && !service.busy
                      onClicked: {
                        root.addOpen = false
                        root.deviceFlow.beginFolderSharing(folderCard.modelData)
                      }
                    }
                    Button {
                      text: folderCard.modelData.paused ? "Forget" : "Rescan"
                      enabled: service.online && !service.busy
                      onClicked: {
                        if (folderCard.modelData.paused)
                          root.requestForget(folderCard.modelData)
                        else service.rescanFolder(folderCard.modelData.id)
                      }
                    }
                  }
                }
              }
            }
          }
        }

        Button {
          visible: root.deviceFlow.view === ""
          Layout.fillWidth: true
          text: root.moreOpen ? "Less" : "More"
          onClicked: root.moreOpen = !root.moreOpen
        }

        ColumnLayout {
          visible: root.moreOpen
          Layout.fillWidth: true

          Button {
            visible: root.deviceFlow.view === ""
            Layout.fillWidth: true
            text: root.addOpen ? "Cancel add folder" : "Add folder"
            enabled: service.online && !service.busy
            onClicked: {
              root.deviceFlow.close()
              root.deviceFlow.resetFolderDraft()
              root.addOpen = !root.addOpen
            }
          }

          ColumnLayout {
            visible: root.addOpen && root.deviceFlow.view === ""
            Layout.fillWidth: true

            Label {
              text: "ADD FOLDER"
              color: "#a6adc8"
              font.bold: true
            }
            Repeater {
              model: service.pendingFolderOffers()
              delegate: Button {
                required property var modelData
                Layout.fillWidth: true
                text: (modelData.encrypted ? "Encrypted offer: " : "Accept ")
                  + modelData.label + " from "
                  + service.deviceName(modelData.deviceId)
                enabled: !modelData.encrypted
                onClicked: idField.text
                    = root.deviceFlow.selectPendingFolder(modelData)
              }
            }
            TextField {
              id: pathField
              Layout.fillWidth: true
              placeholderText: "/path/to/existing/folder"
            }
            TextField {
              id: labelField
              Layout.fillWidth: true
              placeholderText: "Label"
            }
            RowLayout {
              Layout.fillWidth: true
              TextField {
                id: idField
                Layout.fillWidth: true
                placeholderText: "Folder ID"
              }
              Button {
                text: "New ID"
                enabled: service.online && !service.busy
                onClicked: service.requestFolderIdSuggestion()
              }
            }
            Label {
              Layout.fillWidth: true
              text: "Reuse the exact ID to rejoin a remote folder. "
                + "A new ID creates a different folder identity."
              color: "#a6adc8"
              wrapMode: Text.Wrap
            }
            Repeater {
              model: service.shareableDevices()
              delegate: Button {
                required property var modelData
                Layout.fillWidth: true
                text: (root.deviceFlow.draftIds.indexOf(modelData.id) >= 0
                  ? "[x] Share with " : "[ ] Share with ")
                  + String(modelData.name || root.deviceFlow.shortId(modelData.id))
                onClicked: root.deviceFlow.toggleDraft(String(modelData.id || ""))
              }
            }
            Button {
              Layout.fillWidth: true
              text: service.busy ? "Adding..." : "Add folder"
              enabled: service.online && !service.busy
                && pathField.text.length > 0 && idField.text.length > 0
              onClicked: service.addFolder({
                path: pathField.text,
                label: labelField.text,
                folderId: idField.text,
                deviceIds: root.deviceFlow.draftIds,
                pendingDeviceId: root.deviceFlow.pendingDeviceId(idField.text)
              })
            }
          }

          Label {
            visible: root.deviceFlow.view === ""
            Layout.fillWidth: true
            text: "REMOTE DEVICES"
            color: "#a6adc8"
            font.bold: true
          }

          Repeater {
            model: root.deviceFlow.view === "" ? service.remoteDevices() : []
            delegate: RowLayout {
              required property var modelData
              Layout.fillWidth: true
              Label {
                Layout.fillWidth: true
                text: String(modelData.name || root.deviceFlow.shortId(modelData.id))
                  + " · " + service.folderIdsForDevice(modelData.id).length
                  + " folders · "
                  + (modelData.connected ? "connected" : "disconnected")
                color: modelData.connected ? "#a6e3a1" : "#a6adc8"
                elide: Text.ElideRight
              }
              Button {
                text: "Folders"
                enabled: !service.busy
                onClicked: {
                  root.addOpen = false
                  root.deviceFlow.beginDeviceFolders(modelData)
                }
              }
            }
          }

          Button {
            visible: root.deviceFlow.view === ""
            Layout.fillWidth: true
            text: "Add remote device"
            enabled: service.online && !service.busy
            onClicked: {
              root.addOpen = false
              root.deviceFlow.beginAddDevice(null)
            }
          }

          Repeater {
            model: root.deviceFlow.view === "" ? service.pendingDevices : []
            delegate: RowLayout {
              required property var modelData
              Layout.fillWidth: true
              Label {
                Layout.fillWidth: true
                text: String(modelData.name || root.deviceFlow.shortId(modelData.id))
                  + " wants to connect"
                color: "#cdd6f4"
                elide: Text.ElideRight
              }
              Button {
                text: "Accept"
                enabled: !service.busy
                onClicked: {
                  root.addOpen = false
                  root.deviceFlow.beginAddDevice(modelData)
                }
              }
              Button {
                text: "Dismiss"
                enabled: !service.busy
                onClicked: {
                  root.addOpen = false
                  root.deviceFlow.beginDismissDevice(modelData)
                }
              }
            }
          }

          ColumnLayout {
            visible: root.deviceFlow.view === "add-device"
            Layout.fillWidth: true
            Label {
              Layout.fillWidth: true
              text: "ADD REMOTE DEVICE"
              color: "#a6adc8"
              font.bold: true
            }
            Repeater {
              model: service.nearbyDevices
              delegate: Button {
                required property var modelData
                Layout.fillWidth: true
                text: "Use nearby " + root.deviceFlow.shortId(modelData.id)
                onClicked: root.deviceFlow.targetDeviceId = String(modelData.id || "")
              }
            }
            TextField {
              Layout.fillWidth: true
              placeholderText: "Device ID"
              text: root.deviceFlow.targetDeviceId
              onTextChanged: root.deviceFlow.targetDeviceId = text.toUpperCase()
            }
            TextField {
              Layout.fillWidth: true
              placeholderText: "Remote device name (optional)"
              text: root.deviceFlow.targetDeviceName
              onTextChanged: root.deviceFlow.targetDeviceName = text
            }
            RowLayout {
              Button {
                text: "Cancel"
                onClicked: root.deviceFlow.close()
              }
              Button {
                text: service.busy ? "Adding..." : "Add"
                enabled: !service.busy && root.deviceFlow.targetDeviceId !== ""
                onClicked: service.addDevice(root.deviceFlow.targetDeviceId,
                  root.deviceFlow.targetDeviceName)
              }
            }
          }

          ColumnLayout {
            visible: root.deviceFlow.view === "share-folder"
            Layout.fillWidth: true
            Label {
              Layout.fillWidth: true
              text: "SHARE " + service.folderLabel(root.deviceFlow.targetFolderId)
              color: "#a6adc8"
              font.bold: true
            }
            Repeater {
              model: service.shareableDevices()
              delegate: Button {
                required property var modelData
                Layout.fillWidth: true
                text: (root.deviceFlow.draftIds.indexOf(modelData.id) >= 0
                  ? "[x] " : "[ ] ")
                  + String(modelData.name || root.deviceFlow.shortId(modelData.id))
                onClicked: root.deviceFlow.toggleDraft(String(modelData.id || ""))
              }
            }
            RowLayout {
              Button {
                text: "Cancel"
                onClicked: root.deviceFlow.close()
              }
              Button {
                text: "Save sharing"
                enabled: !service.busy
                onClicked: service.setFolderSharing(
                  root.deviceFlow.targetFolderId, root.deviceFlow.draftIds)
              }
            }
          }

          ColumnLayout {
            visible: root.deviceFlow.view === "device-folders"
            Layout.fillWidth: true
            Label {
              Layout.fillWidth: true
              text: "SHARED WITH " + (root.deviceFlow.targetDeviceName
                || root.deviceFlow.shortId(root.deviceFlow.targetDeviceId))
              color: "#a6adc8"
              font.bold: true
            }
            Repeater {
              model: service.folderIdsForDevice(root.deviceFlow.targetDeviceId)
              delegate: Button {
                required property var modelData
                Layout.fillWidth: true
                text: (root.deviceFlow.draftIds.indexOf(modelData) >= 0
                  ? "[x] " : "[ ] ") + service.folderLabel(modelData)
                onClicked: root.deviceFlow.toggleDraft(String(modelData || ""))
              }
            }
            RowLayout {
              Button {
                text: "Cancel"
                onClicked: root.deviceFlow.close()
              }
              Button {
                text: "Save sharing"
                enabled: !service.busy && root.deviceFlow.removedFolderIds().length > 0
                onClicked: service.removeDeviceFolderShares(
                  root.deviceFlow.targetDeviceId, root.deviceFlow.removedFolderIds(),
                  root.deviceFlow.targetDeviceName)
              }
            }
          }

          Rectangle {
            visible: root.deviceFlow.view === "dismiss-device"
            Layout.fillWidth: true
            implicitHeight: dismissDeviceContent.implicitHeight + 16
            color: "#313244"
            border.width: 1
            border.color: "#f38ba8"
            radius: 8
            ColumnLayout {
              id: dismissDeviceContent
              anchors.fill: parent
              anchors.margins: 8
              Label {
                Layout.fillWidth: true
                text: "Dismiss pending request from "
                  + (root.deviceFlow.targetDeviceName
                    || root.deviceFlow.shortId(root.deviceFlow.targetDeviceId)) + "?"
                color: "#f38ba8"
              }
              RowLayout {
                Button {
                  text: "Cancel"
                  onClicked: root.deviceFlow.close()
                }
                Button {
                  text: "Dismiss"
                  enabled: !service.busy
                  onClicked: service.dismissPendingDevice(
                    root.deviceFlow.targetDeviceId, root.deviceFlow.targetDeviceName)
                }
              }
            }
          }
        }

        Rectangle {
          visible: root.pendingForgetId !== ""
          Layout.fillWidth: true
          implicitHeight: forgetContent.implicitHeight + 16
          color: "#313244"
          border.width: 1
          border.color: "#f38ba8"
          radius: 8

          ColumnLayout {
            id: forgetContent
            anchors.fill: parent
            anchors.margins: 8

            Label {
              Layout.fillWidth: true
              text: "Forget " + root.pendingForgetLabel + " ("
                + root.pendingForgetId + ")? The directory and data files "
                + "will not be deleted. Rejoining requires this Folder ID."
              color: "#f38ba8"
              wrapMode: Text.Wrap
            }
            RowLayout {
              Button {
                text: "Cancel"
                onClicked: root.pendingForgetId = ""
              }
              Button {
                text: "Forget"
                enabled: !service.busy
                onClicked: root.confirmForget()
              }
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Button {
            text: "Web UI"
            enabled: service.online
            onClicked: service.openWebUi()
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Button {
            text: "Rescan all"
            enabled: service.online && !service.busy
              && service.folderCount > 0
            onClicked: service.rescanAllFolders()
          }
          Button {
            text: "Refresh status"
            enabled: !service.busy && !service.refreshing
            onClicked: service.refresh()
          }
        }
      }
    }
  }

  Connections {
    target: service
    function onFolderIdSuggestionChanged() {
      if (!idField.activeFocus && service.folderIdSuggestion)
        idField.text = service.folderIdSuggestion
    }
    function onActionFinished(action, ok) {
      root.deviceFlow.actionFinished(action, ok)
    }
  }
}
