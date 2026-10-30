pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import "."
import "../models/PanelModel.js" as Model

// Omarchy's outlined device card: name and ID chip with the state on the
// right, then shares, rates and address with Pause beside them.
StyledRect {
    id: root
    required property var controller
    readonly property var device: controller.device
    readonly property int sharedCount: device ? controller.service.folderIdsForDevice(device.id).length : 0
    readonly property int totalCount: controller.service.folders.length
    function rate(key) {
        return device && controller.fresh ? Model.bytes(device[key]) + "/s" : "Unknown";
    }
    implicitHeight: content.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.medium
    color: Colours.tPalette.m3surfaceContainerLow
    border.width: 1
    border.color: Colours.palette.m3outlineVariant
    component InfoRow: RowLayout {
        property string icon: ""
        property string text: ""
        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall
        MaterialIcon {
            text: parent.icon
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.label.medium
        }
        StyledText {
            Layout.fillWidth: true
            text: parent.text
            textFormat: Text.PlainText
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
            elide: Text.ElideMiddle
        }
    }
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
                icon: "computer"
                caption: root.device ? root.device.name || "Unnamed device" : "No remote device"
                help: "Open this device in the Web UI"
                disabled: !root.device || !root.controller.service.online
                onClicked: root.controller.service.openWebUi()
            }
            SharedWidgetIdCopyButton {
                id: copyButton
                visible: !!root.device
                value: root.device ? root.device.id : ""
                caption: ""
                help: "Copy device ID"
            }
            Item {
                Layout.fillWidth: true
            }
            StyledText {
                id: stateText
                text: Model.deviceStatus(root.device, root.controller.fresh)
                color: Model.statusColour(Colours.palette, Model.deviceStateRole(text))
                font.weight: Font.Bold
            }
        }
        // Spare height from the taller tab stays inside the card.
        Item {
            Layout.fillHeight: true
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.padding.small
                spacing: 2
                visible: !!root.device
                InfoRow {
                    icon: "folder"
                    text: root.sharedCount + "/" + root.totalCount + " folder" + (root.totalCount === 1 ? "" : "s") + " shared"
                }
                RowLayout {
                    Layout.fillWidth: true
                    InfoRow {
                        Layout.fillWidth: false
                        icon: "download"
                        text: root.rate("downloadBps")
                    }
                    InfoRow {
                        icon: "upload"
                        text: root.rate("uploadBps")
                    }
                }
                InfoRow {
                    icon: "lan"
                    text: root.device ? root.device.address || "Address unavailable" : ""
                }
            }
            StyledText {
                Layout.fillWidth: true
                visible: !root.device
                text: "Add a remote device to share folders."
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }
            SharedWidgetBusyButton {
                Layout.alignment: Qt.AlignBottom
                visible: !!root.device
                readonly property bool paused: !!root.device?.paused
                icon: paused ? "play_arrow" : "pause"
                caption: paused ? "Resume" : "Pause"
                busyCaption: paused ? "Resuming..." : "Pausing..."
                help: paused ? "Resume synchronization with this device" : "Pause synchronization with this device"
                busy: root.controller.service.busy && ["device.pause", "device.resume"].includes(root.controller.service._actionName) && root.controller.service._actionTargetId === root.device?.id
                disabled: !root.device || !root.controller.fresh || root.controller.busy
                onClicked: root.controller.send(paused ? "device.resume" : "device.pause", {
                    deviceId: root.device.id,
                    deviceName: root.device.name || ""
                })
            }
        }
    }
}
