import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets

ColumnLayout {
    id: root
    required property var controller
    property var parentPopout: null
    spacing: Theme.spacingS
    readonly property var offers: controller.service ? controller.service.pendingFolderOffers() : []
    property string selectedOfferKey: ""
    readonly property var selectedOffer: offers.find(offer => offerKey(offer) === selectedOfferKey) || offers[0] || null
    function offerKey(offer) {
        return offer.folderId + "\n" + offer.deviceId;
    }
    function focusSelector() {
        selector.focusTrigger();
    }
    RowLayout {
        Layout.fillWidth: true
        BodyTabFoldersSelector {
            id: selector
            Layout.fillWidth: true
            controller: root.controller
            parentPopout: root.parentPopout
        }
        SharedWidgetSquareActionButton {
            iconName: "add"
            help: "Add folder (locally)"
            enabled: root.controller.fresh && !root.controller.busy
            onClicked: root.controller.begin("add-folder", {}, this)
        }
        SharedWidgetSquareActionButton {
            iconName: "share"
            help: "Share folder\n(other device)"
            enabled: !!root.controller.folder && root.controller.fresh && !root.controller.busy
            onClicked: root.controller.begin("share-folder", root.controller.folder, this)
        }
        SharedWidgetSquareActionButton {
            readonly property bool paused: !!root.controller.folder && root.controller.folder.paused
            iconName: paused ? "link" : "close"
            help: root.controller.folder ? (paused ? "Link folder" : "Unlink folder (locally)") : "Select a folder"
            success: paused
            danger: !paused
            busy: !!root.controller.service && root.controller.service.busy && ["folder.pause", "folder.resume"].indexOf(root.controller.service._actionName) >= 0
            enabled: !!root.controller.folder && root.controller.fresh && !root.controller.busy
            onClicked: root.controller.toggleFolder(this)
        }
    }
    BodyTabFoldersCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        controller: root.controller
    }
    // Omarchy's pending requests: one selector with accept and reject.
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.offers.length > 0
        spacing: Theme.spacingXS
        StyledText {
            text: "Pending folder requests"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.onSurfaceVariant
        }
        RowLayout {
            Layout.fillWidth: true
            SharedWidgetDropdown {
                Layout.fillWidth: true
                options: root.offers.map(offer => ({
                            value: root.offerKey(offer),
                            label: offer.label,
                            description: "from " + root.controller.service.deviceName(offer.deviceId) + (offer.label === offer.folderId ? "" : " · " + offer.folderId)
                        }))
                value: root.selectedOffer ? root.offerKey(root.selectedOffer) : ""
                placeholder: "No pending requests"
                parentPopout: root.parentPopout
                onSelected: value => root.selectedOfferKey = value
            }
            SharedWidgetSquareActionButton {
                iconName: "check"
                success: true
                help: root.selectedOffer && root.selectedOffer.encrypted ? "Open Web UI to set up this encrypted share" : "Accept folder request"
                enabled: !!root.selectedOffer && root.controller.fresh && !root.controller.busy
                onClicked: {
                    if (root.selectedOffer.encrypted)
                        root.controller.service.openWebUi();
                    else
                        root.controller.begin("add-folder", root.selectedOffer, this);
                }
            }
            SharedWidgetSquareActionButton {
                iconName: "close"
                danger: true
                help: "Reject folder request"
                enabled: !!root.selectedOffer && root.controller.fresh && !root.controller.busy
                onClicked: root.controller.requestConfirmation("folder.dismiss-pending", Object.assign({
                        deviceName: root.controller.service.deviceName(root.selectedOffer.deviceId)
                    }, root.selectedOffer), this)
            }
        }
        StyledText {
            Layout.fillWidth: true
            visible: !!root.selectedOffer && root.selectedOffer.encrypted
            text: "Encrypted or untrusted shares require setup in Web UI."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.warning
            wrapMode: Text.Wrap
        }
    }
}
