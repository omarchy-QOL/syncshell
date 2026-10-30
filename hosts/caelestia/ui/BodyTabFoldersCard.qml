pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import "."
import "../models/PanelModel.js" as Model
import "../../../shared/Paths.js" as Paths

// Omarchy's outlined folder card: name and ID chip with the state on the
// right, then meta and path with the folder action beside them.
StyledRect {
    id: root
    required property var controller
    readonly property var folder: controller.folder
    implicitHeight: content.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.medium
    color: Colours.tPalette.m3surfaceContainerLow
    border.width: 1
    border.color: Colours.palette.m3outlineVariant
    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall
            SharedWidgetBusyButton {
                id: nameButton
                maxCaptionWidth: content.width - copyButton.width - stateText.implicitWidth - iconLabel.implicitWidth - spacing - horizontalPadding * 2 - Tokens.spacing.medium * 2
                icon: "folder"
                caption: root.folder ? Model.label(root.folder) : "No folder selected"
                help: root.folder?.path ? "Open " + root.folder.path : "Folder unavailable"
                disabled: !root.folder?.path
                onClicked: Qt.openUrlExternally(Model.fileUrl(Paths.resolveFolderPath(root.folder.path, root.controller.service.homePath)))
            }
            SharedWidgetIdCopyButton {
                id: copyButton
                visible: !!root.folder
                value: root.folder ? root.folder.id : ""
                caption: ""
                help: "Copy folder ID"
            }
            Item {
                Layout.fillWidth: true
            }
            StyledText {
                id: stateText
                text: root.folder ? root.controller.folderStatus(root.folder) : ""
                color: Model.statusColour(Colours.palette, Model.folderStateRole(text))
                font.weight: Font.Bold
                SharedWidgetToolTip {
                    visible: stateHover.hovered && !!stateText.text
                    text: Model.stateHelp(stateText.text)
                }
                HoverHandler {
                    id: stateHover
                }
            }
        }
        StyledText {
            id: activityLabel
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: !!text
            text: root.controller.folderActivity(root.folder)
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
            maximumLineCount: 1
            font: Tokens.font.label.medium
            color: Model.statusColour(Colours.palette, Model.activityRole(root.controller.service ? root.controller.service.currentActivity.action : ""))
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.padding.small
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    visible: !!root.folder
                    text: Model.folderMeta(root.folder, root.controller.fresh, root.controller.service.localDeviceId, root.controller.rescanning(root.folder))
                    textFormat: Text.PlainText
                    color: Model.hasErrors(root.folder) ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: !!root.folder?.path
                    text: root.folder?.path || ""
                    textFormat: Text.PlainText
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                    elide: Text.ElideLeft
                }
            }
            SharedWidgetBusyButton {
                Layout.alignment: Qt.AlignBottom
                readonly property bool paused: !!root.folder?.paused
                icon: paused ? "delete" : "refresh"
                caption: paused ? "Forget" : "Rescan"
                busyCaption: paused ? "Forgetting..." : "Rescanning..."
                busy: root.controller.rescanning(root.folder)
                help: !root.controller.fresh ? "Refresh current status before changing this folder" : paused ? "Remove only this unlinked Syncthing configuration" : "Rescan this folder for local changes"
                disabled: !root.folder || !root.controller.fresh || root.controller.busy
                onClicked: {
                    if (!paused)
                        root.controller.service.rescanFolder(root.folder.id);
                    else
                        root.controller.confirm("folder.forget", {
                            folderId: root.folder.id
                        }, "Forget " + Model.label(root.folder) + " (" + root.folder.id + ")?", "This removes only its Syncthing configuration. The directory and data files will not be deleted. " + (root.folder.markerName === ".stfolder" ? "Syncthing will also attempt to remove its internal .stfolder marker. " : "") + "Rejoining the same remote folder requires this exact Folder ID.");
                }
            }
        }
        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            text: Model.errorDetails(root.folder)
            textFormat: Text.PlainText
            visible: !!text
            color: Colours.palette.m3error
            font: Tokens.font.label.medium
            wrapMode: Text.Wrap
        }
    }
}
