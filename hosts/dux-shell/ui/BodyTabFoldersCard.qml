import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.DCommon.Widgets
import "../models/PanelModel.js" as Model
import "UiConstants.js" as UiConstants

StyledRect {
    id: root
    required property var controller
    readonly property var folder: controller.folder
    readonly property var status: folder ? folder.status || {} : ({})
    implicitHeight: content.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.cardSurface
    border.width: Theme.outlineWidth
    border.color: Theme.outlineVariant
    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS
        // Omarchy's card head: name button, ID copy button, state on the right.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXS
            SharedWidgetTooltipButton {
                id: nameButton
                Layout.maximumWidth: content.width - copyButton.width - stateText.implicitWidth - Theme.spacingXS * 2 - Theme.spacingM
                leftAlign: true
                iconName: "folder"
                fontSize: Theme.fontSizeMedium
                text: root.folder ? Model.folderName(root.folder) : "No folder selected"
                help: root.folder && root.folder.path ? "Open " + root.folder.path : "Folder unavailable"
                enabled: !!root.folder && !!root.folder.path
                onClicked: Quickshell.execDetached(["dms", "open", root.folder.path])
            }
            SharedWidgetIdCopyButton {
                id: copyButton
                controlHeight: nameButton.height
                caption: ""
                value: root.folder ? root.folder.id : ""
                helpText: "Copy folder ID"
            }
            Item {
                Layout.fillWidth: true
            }
            StyledText {
                id: stateText
                text: root.folder ? root.controller.folderStatus(root.folder) : ""
                color: !root.controller.fresh ? Theme.onSurfaceVariant : Model.folderGroup(root.folder || {}, true) === "errors" ? Theme.error : Theme.primary
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
            }
        }
        BodyTabFoldersCardActivity {
            Layout.fillWidth: true
            service: root.controller.service
            folderId: root.folder ? root.folder.id : ""
        }
        // Spare tab height stays inside the card, above the details, so both
        // tabs keep one panel height.
        Item {
            Layout.fillHeight: true
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingS
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXS
                    StyledText {
                        Layout.fillWidth: true
                        text: Model.folderMeta(root.folder, root.controller.fresh, root.controller.service ? root.controller.service.localDeviceId : "", root.controller.rescanning(root.folder))
                        textFormat: Text.PlainText
                        color: Model.hasErrors(root.folder) ? Theme.error : Theme.onSurfaceVariant
                        font.pixelSize: Theme.fontSizeSmall
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }
                    SharedWidgetTooltipButton {
                        visible: Model.hasErrors(root.folder)
                        flat: true
                        controlHeight: Theme.fontSizeSmall + 4
                        text: '(see "More" below)'
                        help: "Show folder errors"
                        onClicked: root.controller.moreOpen = true
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: !!root.folder && !!root.folder.path
                    text: root.folder ? root.folder.path : ""
                    textFormat: Text.PlainText
                    color: Theme.onSurfaceVariant
                    font.pixelSize: Theme.fontSizeSmall
                    maximumLineCount: 1
                    elide: Text.ElideLeft
                    SharedWidgetToolTip {
                        anchors.fill: parent
                        text: parent.text
                    }
                }
            }
            SharedWidgetBusyButton {
                Layout.alignment: Qt.AlignBottom
                controlHeight: UiConstants.SMALL_CONTROL_HEIGHT
                iconName: root.folder && root.folder.paused ? "delete" : "refresh"
                text: root.folder && root.folder.paused ? "Forget" : "Rescan"
                busyText: root.folder && root.folder.paused ? "Forgetting" : "Rescanning"
                help: !root.controller.fresh ? "Refresh current status before changing this folder" : root.folder && root.folder.paused ? "Remove only this unlinked Syncthing configuration" : "Rescan this folder for local changes"
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
