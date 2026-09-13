import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
  id: root

  layerNamespacePlugin: "syncshell"
  popoutWidth: 480
  popoutHeight: 680
  property var service: null
  property bool moreOpen: false
  property bool addOpen: false
  property string pendingForgetId: ""
  property string pendingForgetLabel: ""

  function requestForget(folder) {
    pendingForgetId = String(folder.id || "")
    pendingForgetLabel = String(folder.label || folder.id || "folder")
  }

  function confirmForget() {
    if (pendingForgetId === "" || !service) return
    if (service.forgetFolder(pendingForgetId)) pendingForgetId = ""
  }

  function resolveService() {
    service = pluginService && pluginId
      ? pluginService.getGlobalVar(pluginId, "service", null) : null
  }

  function stateIcon() {
    if (!service || !service.online) return "cloud_off"
    if (service.folderProblemCount > 0) return "sync_problem"
    return service.syncingFolderCount > 0 ? "sync" : "cloud_done"
  }

  Component.onCompleted: resolveService()
  onPluginServiceChanged: resolveService()
  onPluginIdChanged: resolveService()

  Connections {
    target: root.pluginService
    function onGlobalVarChanged(changedPluginId, variableName) {
      if (changedPluginId === root.pluginId && variableName === "service")
        root.resolveService()
    }
  }

  Timer {
    interval: 50
    repeat: true
    running: !root.service
    onTriggered: root.resolveService()
  }

  horizontalBarPill: Component {
    Row {
      spacing: Theme.spacingXS
      DankIcon {
        anchors.verticalCenter: parent.verticalCenter
        name: root.stateIcon()
        color: root.service && root.service.folderProblemCount > 0
          ? Theme.error : Theme.primary
        size: Theme.iconSize - 4
      }
      StyledText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.service ? String(root.service.folderCount) : "-"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeMedium
      }
    }
  }

  verticalBarPill: Component {
    Column {
      spacing: Theme.spacingXS
      DankIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        name: root.stateIcon()
        color: root.service && root.service.folderProblemCount > 0
          ? Theme.error : Theme.primary
        size: Theme.iconSize - 4
      }
      StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.service ? String(root.service.folderCount) : "-"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeSmall
      }
    }
  }

  popoutContent: Component {
    PopoutComponent {
      headerText: "Syncshell"
      detailsText: root.service ? root.service.summaryText
        : "Starting native core"
      showCloseButton: true

      Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
          width: parent.width
          visible: text !== ""
          text: root.service
            ? root.service.lastError || root.service.actionNotice : ""
          color: root.service && root.service.lastError
            ? Theme.error : Theme.primary
          wrapMode: Text.WordWrap
        }

        StyledText {
          width: parent.width
          visible: root.service && root.service.activityText !== ""
          text: root.service ? root.service.activityText : ""
          color: Theme.surfaceVariantText
          elide: Text.ElideMiddle
        }

        StyledText {
          text: "FOLDERS"
          color: Theme.surfaceVariantText
          font.weight: Font.DemiBold
        }

        Flickable {
          width: parent.width
          height: 330
          clip: true
          contentWidth: width
          contentHeight: folderColumn.implicitHeight

          Column {
            id: folderColumn
            width: parent.width
            spacing: Theme.spacingS

            StyledText {
              width: parent.width
              visible: !root.service || root.service.folders.length === 0
              text: root.service ? root.service.summaryText
                : "Starting native core"
              color: Theme.surfaceVariantText
              horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
              model: root.service ? root.service.folders : []
              delegate: StyledRect {
                required property var modelData
                width: folderColumn.width
                height: details.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh

                Column {
                  id: details
                  anchors.fill: parent
                  anchors.margins: Theme.spacingM
                  spacing: Theme.spacingXS
                  StyledText {
                    width: parent.width
                    text: String(modelData.label || modelData.id)
                    color: Theme.surfaceText
                    font.weight: Font.DemiBold
                  }
                  StyledText {
                    width: parent.width
                    text: String(modelData.path || "")
                    color: Theme.surfaceVariantText
                    elide: Text.ElideMiddle
                  }
                  StyledText {
                    width: parent.width
                    text: String(modelData.status && modelData.status.error
                      || modelData.status && modelData.status.state || "unknown")
                    color: modelData.status && modelData.status.error
                      ? Theme.error : Theme.surfaceVariantText
                    elide: Text.ElideRight
                  }
                  Row {
                    spacing: Theme.spacingXS
                    DankButton {
                      visible: root.moreOpen
                      text: modelData.paused ? "Link" : "Unlink"
                      buttonHeight: 30
                      enabled: root.service && root.service.online
                        && !root.service.busy
                      onClicked: root.service.setFolderPaused(
                        modelData.id, !modelData.paused)
                    }
                    DankButton {
                      text: modelData.paused ? "Forget" : "Rescan"
                      buttonHeight: 30
                      enabled: root.service && root.service.online
                        && !root.service.busy
                      onClicked: {
                        if (modelData.paused) root.requestForget(modelData)
                        else root.service.rescanFolder(modelData.id)
                      }
                    }
                  }
                }
              }
            }
          }
        }

        DankButton {
          width: parent.width
          text: root.moreOpen ? "Less" : "More"
          iconName: root.moreOpen ? "expand_less" : "expand_more"
          buttonHeight: 34
          onClicked: root.moreOpen = !root.moreOpen
        }

        Column {
          visible: root.moreOpen
          width: parent.width
          spacing: Theme.spacingS

          DankButton {
            width: parent.width
            text: root.addOpen ? "Cancel add folder" : "Add folder"
            buttonHeight: 34
            enabled: root.service && root.service.online
              && !root.service.busy
            onClicked: root.addOpen = !root.addOpen
          }

          Column {
            visible: root.addOpen
            width: parent.width
            spacing: Theme.spacingS

            StyledText {
              text: "ADD FOLDER"
              color: Theme.surfaceText
              font.weight: Font.DemiBold
            }
            DankTextField {
              id: pathField
              width: parent.width
              placeholderText: "/path/to/existing/folder"
              leftIconName: "folder"
              showClearButton: true
            }
            DankTextField {
              id: labelField
              width: parent.width
              placeholderText: "Label"
            }
            Row {
              width: parent.width
              spacing: Theme.spacingS
              DankTextField {
                id: idField
                width: parent.width - suggestButton.width - parent.spacing
                placeholderText: "Folder ID"
              }
              DankButton {
                id: suggestButton
                text: "New ID"
                buttonHeight: 34
                enabled: root.service && root.service.online
                  && !root.service.busy
                onClicked: root.service.requestFolderIdSuggestion()
              }
            }
            StyledText {
              width: parent.width
              text: "Reuse the exact ID to rejoin a remote folder. "
                + "A new ID creates a different folder identity."
              color: Theme.surfaceVariantText
              wrapMode: Text.WordWrap
            }
            DankButton {
              width: parent.width
              text: root.service && root.service.busy
                ? "Adding..." : "Add folder"
              buttonHeight: 34
              enabled: root.service && root.service.online
                && pathField.text !== "" && idField.text !== ""
                && !root.service.busy
              onClicked: root.service.addFolder({
                path: pathField.text,
                label: labelField.text,
                folderId: idField.text,
                deviceIds: []
              })
            }
          }
        }

        StyledRect {
          visible: root.pendingForgetId !== ""
          width: parent.width
          height: forgetContent.implicitHeight + Theme.spacingM * 2
          radius: Theme.cornerRadius
          color: Theme.surfaceContainerHigh

          Column {
            id: forgetContent
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            StyledText {
              width: parent.width
              text: "Forget " + root.pendingForgetLabel + " ("
                + root.pendingForgetId + ")? The directory and data files "
                + "will not be deleted. Rejoining requires this Folder ID."
              color: Theme.error
              wrapMode: Text.WordWrap
            }
            Row {
              spacing: Theme.spacingS
              DankButton {
                text: "Cancel"
                buttonHeight: 32
                onClicked: root.pendingForgetId = ""
              }
              DankButton {
                text: "Forget"
                buttonHeight: 32
                enabled: root.service && !root.service.busy
                onClicked: root.confirmForget()
              }
            }
          }
        }

        Row {
          width: parent.width
          spacing: Theme.spacingS
          DankButton {
            text: "Web UI"
            iconName: "open_in_new"
            buttonHeight: 34
            enabled: root.service && root.service.online
            onClicked: root.service.openWebUi()
          }
        }

        Row {
          width: parent.width
          spacing: Theme.spacingS
          DankButton {
            text: "Rescan all"
            iconName: "sync"
            buttonHeight: 34
            enabled: root.service && root.service.online
              && !root.service.busy && root.service.folderCount > 0
            onClicked: root.service.rescanAllFolders()
          }
          DankButton {
            text: "Refresh status"
            iconName: "refresh"
            buttonHeight: 34
            enabled: root.service && !root.service.busy
              && !root.service.refreshing
            onClicked: root.service.refresh()
          }
        }
      }

      Connections {
        target: root.service
        function onFolderIdSuggestionChanged() {
          if (!idField.getActiveFocus() && root.service.folderIdSuggestion)
            idField.text = root.service.folderIdSuggestion
        }
      }
    }
  }
}
