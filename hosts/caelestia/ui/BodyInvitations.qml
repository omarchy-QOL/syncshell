pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import "."

// Caelestia lists device and folder invitations below both tabs, which share
// one toolbar, so there is no BodyTabDevices; hence this file name.
ColumnLayout {
    id: root
    required property var controller
    signal formRequested(string kind, var target, Item trigger)
    // An empty column would still add the body's spacing above More.
    visible: controller.service.pendingDevices.length + controller.service.pendingFolderOffers().length > 0
    Repeater {
        model: root.controller.service.pendingDevices
        ColumnLayout {
            id: deviceOffer
            required property var modelData
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: (deviceOffer.modelData.name || deviceOffer.modelData.id) + " wants to connect"
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
            }
            RowLayout {
                SharedWidgetBusyButton {
                    id: acceptDevice
                    caption: "Accept"
                    disabled: root.controller.busy
                    onClicked: root.formRequested("accept-device", deviceOffer.modelData, acceptDevice)
                }
                SharedWidgetBusyButton {
                    caption: "Dismiss"
                    disabled: root.controller.busy
                    onClicked: root.controller.confirm("device.dismiss-pending", {
                        deviceId: deviceOffer.modelData.id
                    }, "Dismiss pending request from " + (deviceOffer.modelData.name || deviceOffer.modelData.id) + "?", "It can reappear if the device connects again.")
                }
            }
        }
    }
    Repeater {
        model: root.controller.service.pendingFolderOffers()
        ColumnLayout {
            id: folderOffer
            required property var modelData
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: folderOffer.modelData.label + " offered by " + root.controller.service.deviceName(folderOffer.modelData.deviceId)
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
            }
            StyledText {
                Layout.fillWidth: true
                visible: folderOffer.modelData.encrypted
                text: "Encrypted or untrusted shares require setup in Web UI."
                wrapMode: Text.Wrap
            }
            RowLayout {
                SharedWidgetBusyButton {
                    id: acceptFolder
                    caption: folderOffer.modelData.encrypted ? "Open Web UI" : "Accept"
                    disabled: root.controller.busy
                    onClicked: root.formRequested("add-folder", folderOffer.modelData, acceptFolder)
                }
                SharedWidgetBusyButton {
                    caption: "Dismiss"
                    disabled: root.controller.busy
                    onClicked: root.controller.confirm("folder.dismiss-pending", {
                        folderId: folderOffer.modelData.folderId,
                        pendingDeviceId: folderOffer.modelData.deviceId
                    }, "Dismiss folder invitation?", folderOffer.modelData.label)
                }
            }
        }
    }
}
