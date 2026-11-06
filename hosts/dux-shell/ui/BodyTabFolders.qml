import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets

ColumnLayout {
    id: root
    required property var controller
    property var parentPopout: null
    spacing: Theme.spacingS
    function focusSelector() {
        selector.focusTrigger();
    }
    RowLayout {
        Layout.fillWidth: true
        BodyTabFoldersSelector {
            id: selector
            Layout.fillWidth: true
            controller: root.controller
            parentPopout: root.parentPopout
        }
        SharedWidgetSquareActionButton {
            iconName: "add"
            help: "Add folder"
            enabled: root.controller.fresh && !root.controller.busy
            onClicked: root.controller.begin("add-folder", {}, this)
        }
        SharedWidgetSquareActionButton {
            iconName: "share"
            help: "Choose this folder's devices"
            enabled: !!root.controller.folder && root.controller.fresh && !root.controller.busy
            onClicked: root.controller.begin("share-folder", root.controller.folder, this)
        }
        SharedWidgetSquareActionButton {
            iconName: root.controller.folder && root.controller.folder.paused ? "link" : "link_off"
            help: root.controller.folder && root.controller.folder.paused ? "Resume folder synchronization" : "Pause folder synchronization; keep its files and shares"
            busy: !!root.controller.service && root.controller.service.busy
            enabled: !!root.controller.folder && root.controller.fresh
            onClicked: root.controller.toggleFolder()
        }
    }
    BodyTabFoldersCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        controller: root.controller
    }
    Repeater {
        model: root.controller.service ? root.controller.service.pendingFolderOffers() : []
        ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: "Folder invitation: " + modelData.label + " from " + root.controller.service.deviceName(modelData.deviceId)
                textFormat: Text.PlainText
            }
            StyledText {
                Layout.fillWidth: true
                visible: modelData.encrypted
                text: "Encrypted or untrusted shares require setup in Web UI."
                wrapMode: Text.Wrap
            }
            RowLayout {
                SharedWidgetTooltipButton {
                    primary: true
                    text: modelData.encrypted ? "Open Web UI" : "Accept"
                    enabled: root.controller.fresh && !root.controller.busy
                    onClicked: {
                        if (modelData.encrypted)
                            root.controller.service.openWebUi();
                        else
                            root.controller.begin("add-folder", modelData, this);
                    }
                }
                SharedWidgetTooltipButton {
                    text: "Dismiss"
                    enabled: root.controller.fresh && !root.controller.busy
                    onClicked: root.controller.requestConfirmation("folder.dismiss-pending", modelData, this)
                }
            }
        }
    }
}
