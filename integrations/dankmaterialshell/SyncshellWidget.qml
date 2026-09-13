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
  property var popoutService: null
  property var service: null

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

      headerActions: Component {
        Row {
          spacing: Theme.spacingXS
          DankButton {
            text: "Refresh"
            iconName: "refresh"
            buttonHeight: 32
            enabled: root.service && !root.service.busy
              && !root.service.refreshing
            onClicked: root.service.refresh()
          }
          DankButton {
            text: "Rescan all"
            iconName: "sync"
            buttonHeight: 32
            enabled: root.service && root.service.online
              && !root.service.busy && root.service.folderCount > 0
            onClicked: root.service.rescanAllFolders()
          }
          DankButton {
            text: "Web UI"
            iconName: "open_in_new"
            buttonHeight: 32
            enabled: root.service && root.service.online
            onClicked: root.service.openWebUi()
          }
        }
      }

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
                      text: modelData.paused ? "Resume" : "Pause"
                      buttonHeight: 30
                      enabled: root.service && root.service.online
                        && !root.service.busy
                      onClicked: root.service.setFolderPaused(
                        modelData.id, !modelData.paused)
                    }
                    DankButton {
                      text: "Rescan"
                      buttonHeight: 30
                      enabled: root.service && root.service.online
                        && !modelData.paused && !root.service.busy
                      onClicked: root.service.rescanFolder(modelData.id)
                    }
                    DankButton {
                      text: "Forget"
                      buttonHeight: 30
                      enabled: root.service && root.service.online
                        && modelData.paused && !root.service.busy
                      onClicked: root.service.forgetFolder(modelData.id)
                    }
                  }
                }
              }
            }
          }
        }

        StyledText {
          text: "Add existing directory"
          color: Theme.surfaceText
          font.weight: Font.DemiBold
        }
        DankTextField {
          id: pathField
          width: parent.width
          placeholderText: "/absolute/path"
          leftIconName: "folder"
          showClearButton: true
        }
        Row {
          width: parent.width
          spacing: Theme.spacingS
          DankTextField {
            id: labelField
            width: (parent.width - parent.spacing) * 0.4
            placeholderText: "Label"
          }
          DankTextField {
            id: idField
            width: (parent.width - parent.spacing) * 0.6
            placeholderText: "Folder ID"
          }
        }
        Row {
          spacing: Theme.spacingS
          DankButton {
            text: "Suggest ID"
            buttonHeight: 34
            enabled: root.service && root.service.online
              && !root.service.busy
            onClicked: root.service.requestFolderIdSuggestion()
          }
          DankButton {
            text: root.service && root.service.busy ? "Working" : "Add folder"
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
