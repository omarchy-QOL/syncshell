pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import "."
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var controller
    readonly property var device: controller.device
    RowLayout {
        Layout.fillWidth: true
        StyledText {
            Layout.fillWidth: true
            text: root.device ? Model.label(root.device) : "No remote devices"
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        SharedWidgetIdCopyButton {
            visible: !!root.device
            value: root.device ? root.device.id : ""
            caption: "device ID"
            help: "Copy device ID"
        }
    }
    StyledText {
        Layout.fillWidth: true
        text: Model.deviceStatus(root.device, root.controller.fresh)
    }
    StyledText {
        Layout.fillWidth: true
        text: root.device?.address || ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    StyledText {
        Layout.fillWidth: true
        text: root.controller.fresh ? "Download " + Model.bytes(root.device?.downloadBps) + "/s · Upload " + Model.bytes(root.device?.uploadBps) + "/s" : "Transfer rates unknown"
        wrapMode: Text.Wrap
    }
    StyledText {
        Layout.fillWidth: true
        text: root.device ? Model.plural(root.controller.service.folderIdsForDevice(root.device.id).length, "shared folder") : "No folders shared"
        wrapMode: Text.Wrap
    }
    Flow {
        Layout.fillWidth: true
        spacing: 6
        SharedWidgetBusyButton {
            caption: root.device?.paused ? "Resume" : "Pause"
            disabled: !root.device || !root.controller.fresh || root.controller.busy
            onClicked: root.controller.send(root.device.paused ? "device.resume" : "device.pause", {
                deviceId: root.device.id
            })
        }
        SharedWidgetBusyButton {
            caption: "Remove"
            disabled: !root.device || !root.controller.fresh || root.controller.busy
            onClicked: root.controller.confirm("device.remove", {
                deviceId: root.device.id
            }, "Remove device?", Model.label(root.device) + "\nFiles are kept on both devices.")
        }
    }
}
