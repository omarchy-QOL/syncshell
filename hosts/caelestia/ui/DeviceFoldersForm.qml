pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import "."
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var controller
    readonly property var device: controller.service.device(controller.view.draft.deviceId)
    readonly property var shares: controller.service.folders.filter(f => (f.devices || []).some(d => d.id === controller.view.draft.deviceId))
    function options(confirmed) {
        return shares.filter(f => ["valid", "paused"].includes(Model.remoteShare(f, device || {}, controller.fresh)) === confirmed).map(f => ({
                    value: f.id,
                    label: Model.label(f),
                    detail: [f.path, f.id, Model.remoteShareDescription(Model.remoteShare(f, device || {}, controller.fresh))].filter(Boolean).join(" · ")
                }));
    }
    InlineFormHeader {
        Layout.fillWidth: true
        title: "Device folders"
        busy: root.controller.busy
        onCancelled: root.controller.cancelForm()
    }
    StyledText {
        Layout.fillWidth: true
        text: root.device ? root.device.name || root.device.id : "Device is no longer configured"
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    StyledText {
        text: "Existing shares"
    }
    SyncshellDropdown {
        Layout.fillWidth: true
        multiple: true
        options: root.options(true)
        selectedIds: (root.controller.view.draft.folderIds || []).filter(id => options.some(o => o.value === id))
        disabled: root.controller.busy || !!root.controller.view.confirmation
        onToggled: id => root.controller.draft({
                folderIds: Model.toggle(root.controller.view.draft.folderIds, id)
            })
    }
    RowLayout {
        StyledText {
            text: "Unconfirmed shares"
        }
        StyledText {
            Layout.fillWidth: true
            text: "(acceptance pending/device offline)"
            color: Colours.palette.m3secondary
            elide: Text.ElideRight
            visible: root.options(false).length > 0
        }
    }
    SyncshellDropdown {
        Layout.fillWidth: true
        multiple: true
        options: root.options(false)
        selectedIds: (root.controller.view.draft.folderIds || []).filter(id => options.some(o => o.value === id))
        disabled: root.controller.busy || !!root.controller.view.confirmation
        onToggled: id => root.controller.draft({
                folderIds: Model.toggle(root.controller.view.draft.folderIds, id)
            })
    }
    StyledText {
        Layout.fillWidth: true
        text: "Uncheck shares to remove. Files remain on both devices. Use Share folder to restore a share."
        wrapMode: Text.Wrap
    }
    BusyButton {
        caption: "Review removals"
        busy: root.controller.busy
        onClicked: root.controller.submitForm()
    }
}
