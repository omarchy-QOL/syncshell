import QtQuick
import QtQuick.Layouts
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var style
    required property var controller
    required property var device
    readonly property var service: controller.service
    readonly property var displayStatus: Model.deviceDisplay(device, service.online && service.connection.fresh)
    spacing: style.spacing
    NativeText {
        style: root.style
        Layout.fillWidth: true
        text: root.device.name || root.device.id
    }
    InfoPair {
        style: root.style
        Layout.fillWidth: true
        label: "Status"
        value: root.displayStatus.label
        tone: root.displayStatus.role
    }
    InfoPair {
        style: root.style
        Layout.fillWidth: true
        label: "Address"
        value: root.device.address || "Unknown"
    }
    InfoPair {
        style: root.style
        Layout.fillWidth: true
        label: "Transfer"
        value: "Down " + Model.bytes(root.device.downloadBps) + "/s · Up " + Model.bytes(root.device.uploadBps) + "/s"
    }
    IdCopyButton {
            controller: root.controller
        style: root.style
        value: root.device.id
    }
    Flow {
        Layout.fillWidth: true
        spacing: 4
        BusyButton {
            style: root.style
            objectName: "device-pause"
            text: root.device.paused ? "Resume" : "Pause"
            enabled: root.service.online && !root.controller.blocked
            onClicked: source => {
                root.controller.rememberTrigger(source);
                root.controller.ask(root.device.paused ? "device.resume" : "device.pause", {
                    deviceId: root.device.id
                }, (root.device.paused ? "Resume " : "Pause ") + root.device.name + "?", root.device.id);
            }
        }
        BusyButton {
            style: root.style
            text: "Web UI"
            enabled: root.service.online && !root.controller.blocked
            onClicked: root.service.runAction("webui.open", {
                deviceId: root.device.id
            }, "", root.device.id)
        }
    }
    NativeText {
        style: root.style
        Layout.fillWidth: true
        text: root.displayStatus.help
        muted: true
    }
    Repeater {
        model: root.service.folders.filter(folder => (folder.devices || []).some(member => member.id === root.device.id))
        NativeText {
            required property var modelData
            style: root.style
            Layout.fillWidth: true
            readonly property var share: Model.shareDisplay(modelData.devices.find(member => member.id === root.device.id),
                root.device, root.service.online && root.service.connection.fresh)
            text: (modelData.label || modelData.id) + " · " + share.label + "\n" + share.help
            tone: share.role
        }
    }
}
