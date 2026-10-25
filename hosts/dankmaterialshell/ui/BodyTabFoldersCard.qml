import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets
import "../models/PanelModel.js" as Model
import "UiConstants.js" as UiConstants

StyledRect {
    id: root
    required property var controller
    readonly property var folder: controller.folder
    readonly property var status: folder ? folder.status || {} : ({})
    implicitHeight: content.implicitHeight + Theme.spacingM * 2
    // Outlined like Omarchy's card; the popout already uses the container tone.
    radius: Theme.cornerRadius / 2
    color: "transparent"
    border.width: 1
    border.color: Qt.alpha(Theme.outline, 0.5)
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
            SharedWidgetIdCopyButton {
                value: root.folder ? root.folder.id : ""
                caption: "folder ID"
                helpText: "Copy folder ID"
            }
            StyledText {
                text: root.folder ? root.controller.folderStatus(root.folder) : ""
                color: !root.controller.fresh ? Theme.surfaceVariantText : Model.folderGroup(root.folder || {}, true) === "errors" ? Theme.error : Theme.primary
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
            SharedWidgetToolTip {
                anchors.fill: parent
                text: parent.text
            }
        }
        BodyTabFoldersCardActivity {
            Layout.fillWidth: true
            service: root.controller.service
            folderId: root.folder ? root.folder.id : ""
        }
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: Model.folderMeta(root.folder, root.controller.fresh, root.controller.service ? root.controller.service.localDeviceId : "", root.controller.rescanning(root.folder))
                textFormat: Text.PlainText
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
            SharedWidgetBusyButton {
                controlHeight: UiConstants.SMALL_CONTROL_HEIGHT
                iconName: root.folder && root.folder.paused ? "delete" : "refresh"
                text: root.folder && root.folder.paused ? "Forget" : "Rescan"
                busyText: root.folder && root.folder.paused ? "Forgetting" : "Rescanning"
                help: !root.controller.fresh ? "Refresh current status before changing this folder" : root.folder && root.folder.paused ? "Forget this folder without deleting its files" : "Rescan local changes"
                busy: root.controller.rescanning(root.folder) || root.controller.pendingAction === "folder.forget"
                enabled: !!root.folder && root.controller.fresh && !root.controller.busy
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
