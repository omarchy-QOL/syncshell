import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

ColumnLayout {
    id: root
    required property var controller
    property var parentPopout: null
    spacing: Theme.spacingS
    RowLayout {
        Layout.fillWidth: true
        FolderSelector {
            Layout.fillWidth: true
            controller: root.controller
            parentPopout: root.parentPopout
        }
        SquareActionButton {
            iconName: "add"
            help: "Add folder"
            enabled: root.controller.fresh && !root.controller.busy
            onClicked: root.controller.begin("add-folder", {}, this)
        }
        SquareActionButton {
            iconName: "share"
            help: "Choose this folder's devices"
            enabled: !!root.controller.folder && root.controller.fresh && !root.controller.busy
            onClicked: root.controller.begin("share-folder", root.controller.folder, this)
        }
        SquareActionButton {
            iconName: root.controller.folder && root.controller.folder.paused ? "link" : "link_off"
            help: root.controller.folder && root.controller.folder.paused ? "Resume folder synchronization" : "Pause folder synchronization; keep its files and shares"
            busy: !!root.controller.service && root.controller.service.busy
            enabled: !!root.controller.folder && root.controller.fresh
            onClicked: root.controller.service.setFolderPaused(root.controller.folder.id, !root.controller.folder.paused)
        }
    }
    FolderCard {
        Layout.fillWidth: true
        controller: root.controller
    }
    Repeater {
        model: root.controller.service ? root.controller.service.pendingFolderOffers() : []
        ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: "Folder invitation: " + modelData.label
                textFormat: Text.PlainText
            }
            RowLayout {
                DankButton {
                    text: modelData.encrypted ? "Open Web UI" : "Accept"
                    enabled: root.controller.fresh && !root.controller.busy
                    onClicked: {
                        if (modelData.encrypted)
                            root.controller.service.openWebUi();
                        else
                            root.controller.begin("add-folder", modelData, this);
                    }
                }
                DankButton {
                    text: "Dismiss"
                    enabled: root.controller.fresh && !root.controller.busy
                    onClicked: root.controller.requestConfirmation("folder.dismiss-pending", modelData, this)
                }
            }
        }
    }
}
