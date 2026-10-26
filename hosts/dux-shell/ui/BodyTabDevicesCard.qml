import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets
import "../models/PanelModel.js" as Model
import "UiConstants.js" as UiConstants

StyledRect {
    id: root
    required property var controller
    readonly property var device: controller.device
    readonly property int sharedCount: device && controller.service ? controller.service.folderIdsForDevice(device.id).length : 0
    readonly property int totalCount: controller.service ? controller.service.folders.length : 0
    function rate(key) {
        return device && controller.fresh ? Model.bytes(device[key]) + "/s" : "Unknown";
    }
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
                iconName: "computer"
                fontSize: Theme.fontSizeMedium
                text: root.device ? root.device.name || "Unnamed device" : "No remote device"
                help: "Open this device in the Web UI"
                enabled: !!root.device && !!root.controller.service && root.controller.service.online
                onClicked: root.controller.service.openWebUi()
            }
            SharedWidgetIdCopyButton {
                id: copyButton
                controlHeight: nameButton.height
                caption: ""
                value: root.device ? root.device.id : ""
                helpText: "Copy device ID"
            }
            Item {
                Layout.fillWidth: true
            }
            StyledText {
                id: stateText
                text: Model.deviceStatus(root.device, root.controller.fresh)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                color: Theme[Model.deviceStateRole(text)]
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.spacingS
            spacing: 2
            visible: !!root.device
            Repeater {
                model: [
                    { icon: "folder", text: root.sharedCount + "/" + root.totalCount + " folder" + (root.totalCount === 1 ? "" : "s") + " shared" },
                    { icon: "download", text: root.rate("downloadBps"), icon2: "upload", text2: root.rate("uploadBps") },
                    { icon: "lan", text: root.device ? root.device.address || "Address unavailable" : "" }
                ]
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.spacingXS
                    DIcon {
                        name: modelData.icon
                        size: Theme.fontSizeSmall + 2
                        color: Theme.onSurfaceVariant
                    }
                    StyledText {
                        Layout.fillWidth: !modelData.icon2
                        text: modelData.text
                        textFormat: Text.PlainText
                        color: Theme.onSurfaceVariant
                        font.pixelSize: Theme.fontSizeSmall
                        maximumLineCount: 1
                        elide: Text.ElideMiddle
                    }
                    DIcon {
                        visible: !!modelData.icon2
                        Layout.leftMargin: Theme.spacingS
                        name: modelData.icon2 || ""
                        size: Theme.fontSizeSmall + 2
                        color: Theme.onSurfaceVariant
                    }
                    StyledText {
                        visible: !!modelData.icon2
                        Layout.fillWidth: true
                        text: modelData.text2 || ""
                        color: Theme.onSurfaceVariant
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }
        }
        StyledText {
            Layout.fillWidth: true
            visible: !root.device
            text: "Add a remote device to share folders."
            color: Theme.onSurfaceVariant
            font.pixelSize: Theme.fontSizeSmall
        }
        Item {
            Layout.fillHeight: true
        }
        SharedWidgetBusyButton {
            Layout.alignment: Qt.AlignRight
            controlHeight: UiConstants.SMALL_CONTROL_HEIGHT
            iconName: root.device && root.device.paused ? "play_arrow" : "pause"
            text: root.device && root.device.paused ? "Resume" : "Pause"
            busyText: root.device && root.device.paused ? "Resuming" : "Pausing"
            help: root.device && root.device.paused ? "Resume synchronization with this device" : "Pause synchronization with this device"
            busy: !!root.device && !!root.controller.service && root.controller.service.busy && ["device.pause", "device.resume"].indexOf(root.controller.service._actionName) >= 0 && root.controller.service._actionTargetId === root.device.id
            enabled: !!root.device && root.controller.fresh && !root.controller.busy
            onClicked: root.controller.service.setDevicePaused(root.device.id, !root.device.paused, root.device.name)
        }
    }
}
