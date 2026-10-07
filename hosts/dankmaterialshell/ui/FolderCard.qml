import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets
import "../models/PanelModel.js" as Model

StyledRect {
    id: root
    required property var controller
    readonly property var folder: controller.folder
    readonly property var status: folder ? folder.status || {} : ({})
    implicitHeight: content.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainer
    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS
        RowLayout {
            Layout.fillWidth: true
            DankActionButton {
                iconName: "folder_open"
                tooltipText: "Open directory"
                enabled: !!root.folder
                onClicked: Quickshell.execDetached(["dms", "open", root.folder.path])
            }
            StyledText {
                text: root.folder ? root.folder.label || root.folder.id : "No folder selected"
                textFormat: Text.PlainText
                Layout.fillWidth: true
                maximumLineCount: 1
            }
            IdCopyButton { value: root.folder ? root.folder.id : "" }
            StyledText {
                text: root.folder ? Model.folderStatus(root.folder, root.controller.fresh) : ""
                color: !root.controller.fresh ? Theme.surfaceVariantText
                    : Model.folderGroup(root.folder || {}, true) === "errors" ? Theme.error : Theme.primary
                font.pixelSize: Theme.fontSizeSmall
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: root.folder ? root.folder.path : "Add a folder to start syncing."
            textFormat: Text.PlainText
            color: Theme.surfaceVariantText
            maximumLineCount: 1
            elide: Text.ElideMiddle
            SyncshellToolTip { anchors.fill: parent; text: parent.text }
        }
        ActivityText {
            Layout.fillWidth: true
            service: root.controller.service
            folderId: root.folder ? root.folder.id : ""
        }
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: (root.status.globalFiles || 0) + " files · " + Model.bytes(root.status.globalBytes)
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
            BusyButton {
                text: root.folder && root.folder.paused ? "Forget" : "Rescan"
                busy: !!root.controller.service && root.controller.service.busy
                enabled: !!root.folder && root.controller.fresh && !root.controller.submitting
                onClicked: {
                    if (root.folder.paused)
                        root.controller.requestConfirmation("folder.forget", root.folder, this);
                    else
                        root.controller.service.rescanFolder(root.folder.id);
                }
            }
        }
    }
}
