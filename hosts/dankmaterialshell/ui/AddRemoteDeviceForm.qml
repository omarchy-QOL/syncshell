import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

ColumnLayout {
    id: root
    required property var controller
    property var parentPopout: null
    spacing: Theme.spacingS
    InlineFormHeader {
        Layout.fillWidth: true
        title: "Add remote device"
        enabled: !root.controller.submitting
        onCancelled: root.controller.closeForm()
    }
    StyledText {
        text: "Device source"
    }
    SyncshellDropdown {
        Layout.fillWidth: true
        parentPopout: root.parentPopout
        placeholder: "Custom device ID"
        value: root.controller.draft.deviceId || ""
        options: [
            {
                value: "",
                label: "Custom device ID"
            }
        ].concat((root.controller.service ? root.controller.service.nearbyDevices : []).map(function (device) {
            return {
                value: device.id,
                label: device.id,
                description: (device.addresses || []).join(", ")
            };
        }))
        enabled: !root.controller.busy
        onSelected: value => root.controller.setDraft("deviceId", value)
    }
    DankTextField {
        Layout.fillWidth: true
        labelText: "Device ID"
        text: root.controller.draft.deviceId || ""
        placeholderText: "XXXXXXX-XXXXXXX-..."
        enabled: !root.controller.busy
        onTextEdited: root.controller.setDraft("deviceId", text)
    }
    StyledText {
        Layout.fillWidth: true
        visible: !!root.controller.service && root.controller.service.nearbyDevices.length === 0
        text: "No nearby device found. Use the device ID."
        color: Theme.warning
    }
    DankTextField {
        Layout.fillWidth: true
        labelText: "Remote device name"
        text: root.controller.draft.name || ""
        placeholderText: "Optional"
        enabled: !root.controller.busy
        onTextEdited: root.controller.setDraft("name", text)
    }
    BusyButton {
        Layout.fillWidth: true
        text: "Add remote device"
        busy: root.controller.submitting
        enabled: !!root.controller.service && root.controller.service.online && !!root.controller.draft.deviceId
        onClicked: root.controller.submit()
    }
}
