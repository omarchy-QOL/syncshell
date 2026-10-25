import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var style
    required property var controller
    readonly property var service: controller.service
    spacing: style.spacing
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        text: "Invitations · " + root.service.pendingDevices.length + " devices · " + root.controller.offerRows.length + " folders"
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        text: "No pending invitations"
        muted: true
        visible: root.service.pendingDevices.length === 0 && root.controller.offerRows.length === 0
    }
    SharedWidgetDropdown {
        style: root.style
        controller: root.controller
        Layout.fillWidth: true
        selectorKey: "pending-devices"
        label: root.controller.pendingDevice ? root.controller.pendingDevice.name || root.controller.pendingDevice.id : "Device invitations"
        selectedId: root.controller.pendingDeviceId
        visible: root.service.pendingDevices.length > 0
        options: root.service.pendingDevices.map(device => ({id: device.id,
            label: device.name || device.id, description: device.id + " · " + (device.address || "Address not reported")}))
        onChosen: id => root.controller.pendingDeviceId = id
    }
    RowLayout {
        visible: root.controller.pendingDevice !== null
        SharedWidgetBusyButton {
            objectName: "accept-pending-device"
            style: root.style
            text: "Accept device"
            enabled: root.service.online && !root.controller.blocked
            onClicked: source => {
                root.controller.rememberTrigger(source);
                root.controller.addDevice(root.controller.pendingDevice, true);
            }
        }
        SharedWidgetBusyButton {
            objectName: "dismiss-pending-device"
            style: root.style
            text: "Dismiss"
            enabled: root.service.online && !root.controller.blocked
            onClicked: source => {
                root.controller.rememberTrigger(source);
                var device = root.controller.pendingDevice;
                root.controller.ask("device.dismiss-pending", {deviceId: device.id},
                    "Dismiss device invitation?", (device.name || device.id) + "\n" + device.id);
            }
        }
    }
    SharedWidgetDropdown {
        style: root.style
        controller: root.controller
        Layout.fillWidth: true
        selectorKey: "pending-folders"
        label: root.controller.selectedOffer ? root.controller.selectedOffer.label : "Folder invitations"
        selectedId: root.controller.pendingOfferId
        visible: root.controller.offerRows.length > 0
        options: root.controller.offerRows
        onChosen: id => root.controller.pendingOfferId = id
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        visible: root.controller.selectedOffer !== null
        text: root.controller.selectedOffer ? root.controller.selectedOffer.description : ""
        muted: true
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        visible: !!root.controller.selectedOffer && root.controller.selectedOffer.offer.encrypted
        text: "This offer is encrypted. Use the Web UI to configure the encryption password."
        tone: "warning"
    }
    RowLayout {
        visible: root.controller.selectedOffer !== null
        SharedWidgetBusyButton {
            objectName: "accept-pending-folder"
            style: root.style
            text: root.controller.selectedOffer && root.controller.selectedOffer.offer.encrypted ? "Open Web UI" : "Accept folder"
            enabled: root.service.online && !root.controller.blocked
            onClicked: source => {
                root.controller.rememberTrigger(source);
                root.controller.addFolder(root.controller.selectedOffer.offer);
            }
        }
        SharedWidgetBusyButton {
            objectName: "dismiss-pending-folder"
            style: root.style
            text: "Dismiss"
            enabled: root.service.online && !root.controller.blocked
            onClicked: source => {
                root.controller.rememberTrigger(source);
                var offer = root.controller.selectedOffer.offer;
                root.controller.ask("folder.dismiss-pending", {folderId: offer.folderId, pendingDeviceId: offer.deviceId},
                    "Dismiss folder invitation?", (offer.label || offer.folderId) + "\nFrom " + root.service.deviceName(offer.deviceId));
            }
        }
    }
}
