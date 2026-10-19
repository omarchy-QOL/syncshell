import QtQuick
import QtQuick.Layouts
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var style
    required property var controller
    RowLayout {
        Layout.fillWidth: true
        SyncshellDropdown {
            style: root.style
            controller: root.controller
            Layout.fillWidth: true
            selectorKey: "devices"
            label: root.controller.device ? root.controller.device.name || root.controller.device.id : "Choose device"
            selectedId: root.controller.deviceId
            options: root.controller.service.remoteDevices().map(device => {
                var status = Model.deviceDisplay(device, root.controller.service.online && root.controller.service.connection.fresh);
                return {id: device.id, label: device.name || device.id, description: device.id,
                    status: status.label, role: status.role, help: status.help};
            })
            onChosen: id => root.controller.deviceId = id
        }
        SquareActionButton {
            objectName: "add-device"
            style: root.style
            text: "Add device"
            actionIcon: "add"
            enabled: root.controller.service.online && !root.controller.blocked
            onClicked: source => {
                root.controller.rememberTrigger(source);
                root.controller.addDevice(null, false);
            }
        }
    }
    RowLayout {
        visible: root.controller.device !== null
        BusyButton {
            objectName: "folders"
            style: root.style
            text: "Folders"
            enabled: root.controller.service.online && !root.controller.blocked
            help: "Inspect confirmed and unconfirmed shares or stop sharing selected folders"
            onClicked: source => {
                root.controller.rememberTrigger(source);
                root.controller.deviceFolders(root.controller.device);
            }
        }
        BusyButton {
            objectName: "remove-device"
            style: root.style
            text: "Remove"
            tone: "danger"
            enabled: root.controller.service.online && !root.controller.blocked
            onClicked: source => {
                root.controller.rememberTrigger(source);
                var device = root.controller.device;
                root.controller.ask("device.remove", {deviceId: device.id},
                    "Remove " + (device.name || device.id) + "?", "Stop sharing with this device. Files are kept.\n" + device.id);
            }
        }
    }
    Loader {
        Layout.fillWidth: true
        active: root.controller.device !== null
        sourceComponent: DeviceCard {
            style: root.style
            controller: root.controller
            device: root.controller.device
        }
    }
    NativeText {
        style: root.style
        Layout.fillWidth: true
        visible: !root.controller.device
        text: "No remote devices configured. Add a device or accept an invitation."
    }
}
