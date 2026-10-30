pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "."
import "../models/PanelModel.js" as Model

// Omarchy shows pending requests under each tab's card. Caelestia's tabs
// share one toolbar, so there is no BodyTabFolders or BodyTabDevices file;
// each tab page holds one of these instead.
ColumnLayout {
    id: root
    required property var controller
    signal formRequested(string kind, var target, Item trigger)
    property bool folders: true
    readonly property var rows: folders ? controller.service.pendingFolderOffers().map(offer => ({
                value: offer.folderId + "\n" + offer.deviceId,
                label: offer.label || offer.folderId,
                detail: "from " + controller.service.deviceName(offer.deviceId) + (offer.label && offer.label !== offer.folderId ? " · " + offer.folderId : ""),
                offer: offer
            })) : controller.service.pendingDevices.map(device => ({
                value: device.id,
                label: device.name || device.id,
                detail: [device.address, device.id].filter(Boolean).join(" · "),
                offer: device
            }))
    property string selectedValue: ""
    readonly property var selected: rows.find(row => row.value === selectedValue) || rows[0] || null
    visible: rows.length > 0
    StyledText {
        text: root.folders ? "Pending folder requests" : "Pending device requests"
        font: Tokens.font.label.medium
        color: Colours.palette.m3onSurfaceVariant
    }
    RowLayout {
        Layout.fillWidth: true
        SharedWidgetDropdown {
            Layout.fillWidth: true
            options: root.rows
            value: root.selected ? root.selected.value : ""
            onChosen: value => root.selectedValue = value
        }
        SharedWidgetSquareActionButton {
            id: accept
            icon: "check"
            success: true
            help: root.folders ? (root.selected?.offer.encrypted ? "Open Web UI to set up this encrypted share" : "Accept folder request") : "Accept remote device connection"
            disabled: !root.selected || root.controller.busy
            onClicked: root.formRequested(root.folders ? "add-folder" : "accept-device", root.selected.offer, accept)
        }
        SharedWidgetSquareActionButton {
            icon: "close"
            danger: true
            help: root.folders ? "Reject folder request" : "Dismiss incoming device request"
            disabled: !root.selected || root.controller.busy
            onClicked: {
                const offer = root.selected.offer;
                if (root.folders)
                    root.controller.confirm("folder.dismiss-pending", {
                        folderId: offer.folderId,
                        pendingDeviceId: offer.deviceId
                    }, "Reject folder request for " + (offer.label || offer.folderId) + " (by " + root.controller.service.deviceName(offer.deviceId) + ")?", "This removes the pending announcement without adding the folder.");
                else
                    root.controller.confirm("device.dismiss-pending", {
                        deviceId: offer.id,
                        deviceName: offer.name || ""
                    }, "Dismiss pending request from " + (offer.name || offer.id) + "?", "It can reappear if the device connects again.");
            }
        }
    }
    StyledText {
        Layout.fillWidth: true
        visible: root.folders && !!root.selected?.offer.encrypted
        text: "Encrypted or untrusted shares require setup in Web UI."
        font: Tokens.font.label.medium
        color: Model.statusColour(Colours.palette, "warning")
        wrapMode: Text.Wrap
    }
}
