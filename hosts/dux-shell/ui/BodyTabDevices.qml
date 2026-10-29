import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets

ColumnLayout {
    id: root
    required property var controller
    property var parentPopout: null
    spacing: Theme.spacingS
    readonly property var pendingRows: controller.service ? controller.service.pendingDevices : []
    property string selectedPendingId: ""
    readonly property var selectedPending: pendingRows.find(device => device.id === selectedPendingId) || pendingRows[0] || null
    function focusSelector() {
        selector.focusTrigger();
    }
    RowLayout {
        Layout.fillWidth: true
        SharedWidgetDropdown {
            id: selector
            Layout.fillWidth: true
            searchOwner: root.controller
            searchKey: "deviceSearch"
            options: root.controller.deviceOptions
            value: root.controller.selectedDeviceId
            placeholder: "No remote device"
            parentPopout: root.parentPopout
            onSelected: value => root.controller.selectedDeviceId = value
        }
        SharedWidgetSquareActionButton {
            iconName: "add"
            help: "Add remote device"
            enabled: root.controller.fresh && !root.controller.busy
            onClicked: root.controller.begin("add-device", {}, this)
        }
        SharedWidgetSquareActionButton {
            iconName: "folder_shared"
            help: "Review this device's folder shares"
            enabled: !!root.controller.device && root.controller.fresh && !root.controller.busy
            onClicked: root.controller.begin("device-folders", root.controller.device, this)
        }
        SharedWidgetSquareActionButton {
            iconName: "close"
            danger: true
            help: "Remove device and its shares; keep files"
            enabled: !!root.controller.device && root.controller.fresh && !root.controller.busy
            onClicked: root.controller.requestConfirmation("device.remove", root.controller.device, this)
        }
    }
    BodyTabDevicesCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        controller: root.controller
    }
    // Omarchy's pending requests: one selector with accept and dismiss.
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.pendingRows.length > 0
        spacing: Theme.spacingXS
        StyledText {
            text: "Pending device requests"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.onSurfaceVariant
        }
        RowLayout {
            Layout.fillWidth: true
            SharedWidgetDropdown {
                Layout.fillWidth: true
                options: root.pendingRows.map(device => ({
                            value: device.id,
                            label: device.name || device.id,
                            description: [device.address, device.id].filter(Boolean).join(" · ")
                        }))
                value: root.selectedPending ? root.selectedPending.id : ""
                placeholder: "No pending requests"
                parentPopout: root.parentPopout
                onSelected: value => root.selectedPendingId = value
            }
            SharedWidgetSquareActionButton {
                iconName: "check"
                success: true
                help: "Accept remote device connection"
                enabled: !!root.selectedPending && root.controller.fresh && !root.controller.busy
                onClicked: root.controller.begin("accept-device", root.selectedPending, this)
            }
            SharedWidgetSquareActionButton {
                iconName: "close"
                danger: true
                help: "Dismiss incoming device request"
                enabled: !!root.selectedPending && root.controller.fresh && !root.controller.busy
                onClicked: root.controller.requestConfirmation("device.dismiss-pending", root.selectedPending, this)
            }
        }
    }
}
