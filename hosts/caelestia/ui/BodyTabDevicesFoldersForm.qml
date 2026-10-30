pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "."
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var controller
    readonly property var device: controller.service.device(controller.view.draft.deviceId)
    readonly property var shares: controller.service.folders.filter(f => (f.devices || []).some(d => d.id === controller.view.draft.deviceId))
    readonly property bool hasShares: (controller.view.draft.originalFolderIds || []).length > 0
    readonly property color warning: Model.statusColour(Colours.palette, "warning")
    function options(confirmed) {
        return shares.filter(f => ["valid", "paused"].includes(Model.remoteShare(f, device || {}, controller.fresh)) === confirmed).map(f => ({
                    value: f.id,
                    label: Model.label(f),
                    detail: [f.path, f.id, Model.remoteShareDescription(Model.remoteShare(f, device || {}, controller.fresh))].filter(Boolean).join(" · ")
                }));
    }
    BodyFormHeader {
        Layout.fillWidth: true
        title: "Shared with " + (root.device ? root.device.name || root.device.id : "device")
        busy: root.controller.busy
        onCancelled: root.controller.cancelForm()
    }
    StyledText {
        Layout.fillWidth: true
        visible: !root.hasShares
        text: "No folders are currently shared with this device."
        font: Tokens.font.label.medium
        color: root.warning
        wrapMode: Text.Wrap
    }
    StyledText {
        visible: root.hasShares
        text: "Existing shares"
        font: Tokens.font.label.medium
        color: Colours.palette.m3onSurfaceVariant
    }
    SharedWidgetDropdown {
        Layout.fillWidth: true
        visible: root.hasShares
        multiple: true
        placeholder: options.length ? "No folders selected" : "No confirmed shares"
        options: root.options(true)
        selectedIds: (root.controller.view.draft.folderIds || []).filter(id => options.some(o => o.value === id))
        disabled: !options.length || root.controller.busy || !!root.controller.view.confirmation
        onToggled: id => root.controller.draft({
                folderIds: Model.toggle(root.controller.view.draft.folderIds, id)
            })
    }
    RowLayout {
        visible: root.hasShares
        Layout.fillWidth: true
        StyledText {
            text: "Unconfirmed shares"
            font: Tokens.font.label.medium
            color: Colours.palette.m3onSurfaceVariant
        }
        StyledText {
            Layout.fillWidth: true
            text: "(acceptance pending/device offline)"
            font: Tokens.font.label.medium
            color: root.warning
            elide: Text.ElideRight
            visible: unconfirmed.options.length > 0
        }
    }
    SharedWidgetDropdown {
        id: unconfirmed
        Layout.fillWidth: true
        visible: root.hasShares
        multiple: true
        placeholder: options.length ? "No folders selected" : "No unconfirmed shares"
        options: root.options(false)
        selectedIds: (root.controller.view.draft.folderIds || []).filter(id => options.some(o => o.value === id))
        disabled: !options.length || root.controller.busy || !!root.controller.view.confirmation
        onToggled: id => root.controller.draft({
                folderIds: Model.toggle(root.controller.view.draft.folderIds, id)
            })
    }
    RowLayout {
        visible: root.hasShares
        Layout.fillWidth: true
        spacing: 4
        MaterialIcon {
            text: "warning"
            color: root.warning
            fontStyle: Tokens.font.label.medium
        }
        StyledText {
            text: "Use"
            font: Tokens.font.label.medium
            color: root.warning
        }
        MaterialIcon {
            text: "share"
            color: root.warning
            fontStyle: Tokens.font.label.medium
        }
        StyledText {
            Layout.fillWidth: true
            text: "button (share folder) to restore a folder."
            font: Tokens.font.label.medium
            color: root.warning
            elide: Text.ElideRight
        }
    }
    SharedWidgetBusyButton {
        Layout.fillWidth: true
        visible: root.hasShares
        caption: "Save sharing"
        primary: true
        busyCaption: "Saving..."
        busy: root.controller.busy
        onClicked: root.controller.submitForm()
    }
}
