pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.components.controls
import "."

ColumnLayout {
    id: root
    required property var controller
    BodyFormHeader {
        Layout.fillWidth: true
        title: root.controller.view.form === "accept-device" ? "Accept device" : "Add device"
        busy: root.controller.busy
        onCancelled: root.controller.cancelForm()
    }
    SharedWidgetDropdown {
        Layout.fillWidth: true
        visible: root.controller.view.form !== "accept-device"
        placeholder: "Nearby devices"
        options: root.controller.service.nearbyDevices.map(d => ({
                    value: d.id,
                    label: d.name || d.id,
                    detail: [d.id, (d.addresses || []).join(", ")].filter(Boolean).join(" · ")
                }))
        onChosen: id => root.controller.draft({
                deviceId: id
            })
    }
    StyledTextField {
        Layout.fillWidth: true
        objectName: root.controller.view.form === "accept-device" ? "syncshellInitialFocus" : ""
        placeholderText: "Device name"
        text: root.controller.view.draft.deviceName || ""
        readOnly: root.controller.busy
        onTextEdited: root.controller.draft({
            deviceName: text
        })
    }
    StyledText {
        Layout.fillWidth: true
        visible: root.controller.view.form === "accept-device"
        text: "Observed address: " + (root.controller.view.draft.address || "unknown")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    StyledTextField {
        Layout.fillWidth: true
        objectName: root.controller.view.form === "accept-device" ? "" : "syncshellInitialFocus"
        placeholderText: "Device ID"
        text: root.controller.view.draft.deviceId || ""
        readOnly: root.controller.busy || root.controller.view.form === "accept-device"
        onTextEdited: root.controller.draft({
            deviceId: text
        })
    }
    SharedWidgetBusyButton {
        caption: "Copy ID"
        copyValue: root.controller.view.draft.deviceId || ""
        disabled: !copyValue
    }
    StyledText {
        Layout.fillWidth: true
        visible: root.controller.view.form !== "accept-device" && !root.controller.service.nearbyDevices.length
        text: "No nearby devices found. Paste a Device ID to add one manually."
        wrapMode: Text.Wrap
    }
    StyledText {
        Layout.fillWidth: true
        text: "Add this device on the other device too, then select folders to share."
        wrapMode: Text.Wrap
    }
    SharedWidgetBusyButton {
        caption: "Add device"
        busy: root.controller.busy
        onClicked: root.controller.submitForm()
    }
}
