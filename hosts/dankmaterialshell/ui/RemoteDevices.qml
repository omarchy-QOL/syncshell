import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

ColumnLayout {
    id: root
    required property var controller
    property var parentPopout: null
    spacing: Theme.spacingS
    RowLayout {
        Layout.fillWidth: true
        SyncshellDropdown {
            Layout.fillWidth: true
            options: root.controller.deviceOptions
            value: root.controller.selectedDeviceId
            placeholder: "No remote device"
            parentPopout: root.parentPopout
            onSelected: value => root.controller.selectedDeviceId = value
        }
        SquareActionButton {
            iconName: "add"
            help: "Add remote device"
            enabled: root.controller.fresh && !root.controller.busy
            onClicked: root.controller.begin("add-device", {}, this)
        }
        SquareActionButton {
            iconName: "folder_shared"
            help: "Review this device's folder shares"
            enabled: !!root.controller.device && root.controller.fresh && !root.controller.busy
            onClicked: root.controller.begin("device-folders", root.controller.device, this)
        }
        SquareActionButton {
            iconName: "close"
            help: "Remove device and its shares; keep files"
            enabled: !!root.controller.device && root.controller.fresh && !root.controller.busy
            onClicked: root.controller.requestConfirmation("device.remove", root.controller.device, this)
        }
    }
    DeviceCard {
        Layout.fillWidth: true
        controller: root.controller
    }
    Repeater {
        model: root.controller.service ? root.controller.service.pendingDevices : []
        ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: "Device invitation: " + (modelData.name || modelData.id)
                textFormat: Text.PlainText
            }
            RowLayout {
                DankButton {
                    text: "Accept"
                    enabled: root.controller.fresh && !root.controller.busy
                    onClicked: root.controller.begin("accept-device", modelData, this)
                }
                DankButton {
                    text: "Dismiss"
                    enabled: root.controller.fresh && !root.controller.busy
                    onClicked: root.controller.requestConfirmation("device.dismiss-pending", modelData, this)
                }
            }
        }
    }
}
