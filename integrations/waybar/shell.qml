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
  property string lastStatus: ""

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
    pluginRoot: root.localPath(Qt.resolvedUrl("."))
    hostId: "waybar"
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
    implicitHeight: 700
    anchors.top: true
    anchors.right: true
    margins.top: 42
    margins.right: 10
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "syncshell-waybar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    mask: Region { item: background }

    Keys.onEscapePressed: {
      if (root.pendingForgetId !== "") root.pendingForgetId = ""
      else root.popupOpen = false
    }

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

      ColumnLayout {
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
          Layout.fillWidth: true
          text: "FOLDERS"
          color: "#a6adc8"
          font.bold: true
        }

        Flickable {
          id: folderView
          Layout.fillWidth: true
          Layout.preferredHeight: root.addOpen ? 150 : 300
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
          Layout.fillWidth: true
          text: root.moreOpen ? "Less" : "More"
          onClicked: root.moreOpen = !root.moreOpen
        }

        ColumnLayout {
          visible: root.moreOpen
          Layout.fillWidth: true

          Button {
            Layout.fillWidth: true
            text: root.addOpen ? "Cancel add folder" : "Add folder"
            enabled: service.online && !service.busy
            onClicked: root.addOpen = !root.addOpen
          }

          ColumnLayout {
            visible: root.addOpen
            Layout.fillWidth: true

            Label {
              text: "ADD FOLDER"
              color: "#a6adc8"
              font.bold: true
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
            Button {
              Layout.fillWidth: true
              text: service.busy ? "Adding..." : "Add folder"
              enabled: service.online && !service.busy
                && pathField.text.length > 0 && idField.text.length > 0
              onClicked: service.addFolder({
                path: pathField.text,
                label: labelField.text,
                folderId: idField.text,
                deviceIds: []
              })
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
  }
}
