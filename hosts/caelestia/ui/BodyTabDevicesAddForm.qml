pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import "."
import "../models/PanelModel.js" as Model

// Omarchy's add form; accepting a pending request has its own form.
ColumnLayout {
    id: root
    required property var controller
    readonly property var nearby: root.controller.service.nearbyDevices.map(d => ({
                value: d.id,
                label: d.name || d.id,
                detail: [d.id, (d.addresses || []).join(", ")].filter(Boolean).join(" · ")
            }))
    component Caption: StyledText {
        font: Tokens.font.label.medium
        color: Colours.palette.m3onSurfaceVariant
    }
    BodyFormHeader {
        Layout.fillWidth: true
        title: "Add remote device"
        busy: root.controller.busy
        onCancelled: root.controller.cancelForm()
    }
    Caption {
        text: "Device source"
    }
    SharedWidgetDropdown {
        Layout.fillWidth: true
        placeholder: "Custom device ID"
        options: [{
                value: "",
                label: "Custom device ID",
                detail: "Enter the ID below"
            }].concat(root.nearby)
        value: root.nearby.some(o => o.value === root.controller.view.draft.deviceId) ? root.controller.view.draft.deviceId : ""
        onChosen: id => root.controller.draft({
                deviceId: id
            })
    }
    Caption {
        text: "Device ID"
    }
    SharedWidgetTextField {
        Layout.fillWidth: true
        objectName: "syncshellInitialFocus"
        hint: "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-..."
        text: root.controller.view.draft.deviceId || ""
        readOnly: root.controller.busy
        onTextEdited: root.controller.draft({
            deviceId: text
        })
    }
    StyledText {
        Layout.fillWidth: true
        visible: !root.nearby.length
        text: "No nearby device found. Use the device ID."
        font: Tokens.font.label.medium
        color: Model.statusColour(Colours.palette, "warning")
        wrapMode: Text.Wrap
    }
    Caption {
        text: "Remote device name"
    }
    SharedWidgetTextField {
        Layout.fillWidth: true
        hint: "Optional; adopted from the remote when empty"
        text: root.controller.view.draft.deviceName || ""
        readOnly: root.controller.busy
        onTextEdited: root.controller.draft({
            deviceName: text
        })
    }
    SharedWidgetBusyButton {
        Layout.fillWidth: true
        caption: "Add remote device"
        primary: true
        busyCaption: "Adding..."
        busy: root.controller.busy
        onClicked: root.controller.submitForm()
    }
}
