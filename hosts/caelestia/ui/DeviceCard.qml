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
    StyledText {
        Layout.fillWidth: true
        text: root.device ? Model.label(root.device) : "No remote devices"
        wrapMode: Text.Wrap
    }
    StyledText {
        Layout.fillWidth: true
        text: Model.deviceStatus(root.device, root.controller.fresh)
    }
    StyledText {
        Layout.fillWidth: true
        text: root.device?.address || ""
        wrapMode: Text.Wrap
    }
    StyledText {
        Layout.fillWidth: true
        text: "Download " + Model.bytes(root.device?.downloadBps) + "/s · Upload " + Model.bytes(root.device?.uploadBps) + "/s"
        wrapMode: Text.Wrap
    }
    Flow {
        Layout.fillWidth: true
        spacing: 6
        BusyButton {
            caption: "Copy ID"
            disabled: !root.device
            copyValue: root.device ? root.device.id : ""
        }
        BusyButton {
            caption: root.device?.paused ? "Resume" : "Pause"
            disabled: !root.device || !root.controller.fresh || root.controller.busy
            onClicked: root.controller.send(root.device.paused ? "device.resume" : "device.pause", {
                deviceId: root.device.id
            })
        }
        BusyButton {
            caption: "Remove"
            disabled: !root.device || !root.controller.fresh || root.controller.busy
            onClicked: root.controller.confirm("device.remove", {
                deviceId: root.device.id
            }, "Remove device?", Model.label(root.device) + "\nFiles are kept on both devices.")
        }
    }
}
