import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var style
    required property var controller
    property bool accepting: false
    spacing: style.spacing
    BodyFormHeader {
        style: root.style
        Layout.fillWidth: true
        title: root.accepting ? "Accept device" : "Add device"
        enabled: !root.controller.pending
        onCanceled: root.controller.discard()
    }
    SharedWidgetDropdown {
        style: root.style
        controller: root.controller
        Layout.fillWidth: true
        visible: !root.accepting
        selectorKey: "nearby"
        label: root.controller.draft.sourceId === "manual" ? "Enter ID manually" : "Nearby device"
        selectedId: root.controller.draft.sourceId || "manual"
        enabled: !root.controller.blocked
        options: [{id: "manual", label: "Enter ID manually", description: "Copy the ID from the other peer"}].concat(
            root.controller.service.nearbyDevices.map(device => ({id: device.id,
                label: device.name || device.id, description: (device.addresses || []).join(", ")})))
        onChosen: id => root.controller.chooseDeviceSource(id)
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        visible: !root.accepting && root.controller.service.nearbyDevices.length === 0
        text: "No nearby devices discovered. Copy the device ID from the other peer and enter it manually."
        muted: true
    }
    SharedWidgetFormField {
        id: deviceId
        objectName: "device-id"
        style: root.style
        Layout.fillWidth: true
        text: root.controller.draft.deviceId || ""
        label: "Device ID"
        readOnly: root.accepting || root.controller.pending
        help: root.accepting ? "This is the requesting device's fixed identity." : "Eight groups of seven letters or digits, separated by hyphens."
        onEdited: value => root.controller.edit("deviceId", value)
        onAccepted: root.controller.save()
    }
    SharedWidgetIdCopyButton {
            controller: root.controller
        objectName: "copy-request-device-id"
        style: root.style
        value: root.controller.draft.deviceId || ""
        visible: root.accepting
    }
    SharedWidgetInfoPair {
        style: root.style
        Layout.fillWidth: true
        label: "Observed address"
        value: root.controller.draft.address || "Not reported"
        visible: root.accepting
    }
    SharedWidgetFormField {
        objectName: "device-name"
        style: root.style
        Layout.fillWidth: true
        text: root.controller.draft.deviceName || ""
        label: "Device name (optional)"
        readOnly: root.controller.pending
        onEdited: value => root.controller.edit("deviceName", value)
        onAccepted: root.controller.save()
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        text: "Add this device on the other peer to complete the connection. Share folders separately."
        muted: true
    }
    SharedWidgetNativeText {
        objectName: "device-validation"
        style: root.style
        Layout.fillWidth: true
        text: root.controller.validation
        visible: text !== ""
        tone: "warning"
    }
    SharedWidgetBusyButton {
        objectName: "save-device"
        style: root.style
        text: root.accepting ? "Accept device" : "Add device"
        busy: root.controller.pending
        busyText: "Adding device"
        enabled: !root.controller.validation && root.controller.service.online && !root.controller.blocked
        onClicked: root.controller.save()
    }
    Component.onCompleted: Qt.callLater(deviceId.focusControl)
    Connections {
        target: root.controller
        function onFocusRequested(key) { if (key === "first-field") deviceId.focusControl(); }
    }
}
