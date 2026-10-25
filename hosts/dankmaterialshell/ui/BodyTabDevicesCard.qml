import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import "../models/PanelModel.js" as Model
import "UiConstants.js" as UiConstants

StyledRect {
    id: root
    required property var controller
    readonly property var device: controller.device
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
            DankIcon {
                name: "devices"
                size: Theme.iconSizeSmall
            }
            StyledText {
                Layout.fillWidth: true
                text: root.device ? root.device.name || root.device.id : "No remote device"
                textFormat: Text.PlainText
                maximumLineCount: 1
            }
            SharedWidgetIdCopyButton {
                value: root.device ? root.device.id : ""
                caption: "device ID"
                helpText: "Copy device ID"
            }
            StyledText {
                text: Model.deviceStatus(root.device, root.controller.fresh)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primary
            }
        }
        SharedWidgetInfoPair {
            Layout.fillWidth: true
            label: "Shared folders"
            value: root.device ? String(root.controller.service.folderIdsForDevice(root.device.id).length) : "0"
        }
        SharedWidgetInfoPair {
            Layout.fillWidth: true
            label: "Download / upload"
            value: root.device && root.controller.fresh ? Model.bytes(root.device.downloadBps) + "/s · " + Model.bytes(root.device.uploadBps) + "/s" : "Unknown"
        }
        StyledText {
            Layout.fillWidth: true
            text: root.device ? root.device.address || "No current connection" : "Add a remote device to share folders."
            textFormat: Text.PlainText
            color: Theme.surfaceVariantText
            maximumLineCount: 1
            elide: Text.ElideMiddle
        }
        Item {
            Layout.fillHeight: true
        }
        SharedWidgetBusyButton {
            Layout.alignment: Qt.AlignRight
            controlHeight: UiConstants.SMALL_CONTROL_HEIGHT
            iconName: root.device && root.device.paused ? "play_arrow" : "pause"
            text: root.device && root.device.paused ? "Resume" : "Pause"
            busy: !!root.controller.service && root.controller.service.busy
            enabled: !!root.device && root.controller.fresh
            onClicked: root.controller.service.setDevicePaused(root.device.id, !root.device.paused, root.device.name)
        }
    }
}
