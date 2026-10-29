import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var controller
    property var parentPopout: null
    readonly property bool hasShares: controller.originalShareIds.length > 0
    readonly property var device: controller.service ? controller.service.device(controller.draft.deviceId) : null
    function options(confirmed) {
        return controller.originalShareIds.map(id => controller.service.folder(id)).filter(Boolean).filter(f => ["valid", "paused"].includes(Model.remoteShare(f, device || {}, controller.fresh)) === confirmed).map(f => ({
                    value: f.id,
                    label: Model.folderName(f),
                    description: [f.path, f.id, Model.remoteShareDescription(Model.remoteShare(f, device || {}, controller.fresh))].filter(Boolean).join(" · ")
                }));
    }
    spacing: Theme.spacingS
    BodyFormHeader {
        Layout.fillWidth: true
        title: "Shared with " + (root.controller.draft.name || root.controller.draft.deviceId || "device")
        enabled: !root.controller.submitting
        onCancelled: root.controller.closeForm()
    }
    StyledText {
        visible: !root.hasShares
        Layout.fillWidth: true
        text: "No folders are currently shared with this device."
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.warning
    }
    StyledText {
        visible: root.hasShares
        text: "Existing shares"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.onSurfaceVariant
    }
    SharedWidgetMultiSelect {
        visible: root.hasShares
        Layout.fillWidth: true
        placeholder: options.length ? "No folders selected" : "No confirmed shares"
        parentPopout: root.parentPopout
        options: root.options(true)
        selectedValues: (root.controller.draft.ids || []).filter(id => options.some(o => o.value === id))
        enabled: options.length > 0 && !root.controller.busy
        onToggled: value => root.controller.toggleDraft(value)
    }
    RowLayout {
        visible: root.hasShares
        Layout.fillWidth: true
        spacing: Theme.spacingXS
        StyledText {
            text: "Unconfirmed shares"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.onSurfaceVariant
        }
        StyledText {
            visible: unconfirmedPicker.options.length > 0
            Layout.fillWidth: true
            text: "(acceptance pending/device offline)"
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.warning
        }
    }
    SharedWidgetMultiSelect {
        id: unconfirmedPicker
        visible: root.hasShares
        Layout.fillWidth: true
        placeholder: options.length ? "No folders selected" : "No unconfirmed shares"
        parentPopout: root.parentPopout
        options: root.options(false)
        selectedValues: (root.controller.draft.ids || []).filter(id => options.some(o => o.value === id))
        enabled: options.length > 0 && !root.controller.busy
        onToggled: value => root.controller.toggleDraft(value)
    }
    RowLayout {
        visible: root.hasShares
        Layout.fillWidth: true
        spacing: Theme.spacingXS
        DIcon {
            name: "warning"
            size: Theme.fontSizeSmall + 2
            color: Theme.warning
        }
        StyledText {
            text: "Use"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.warning
        }
        DIcon {
            name: "share"
            size: Theme.fontSizeSmall + 2
            color: Theme.warning
        }
        StyledText {
            Layout.fillWidth: true
            text: "button (share folder) to restore a folder."
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.warning
        }
    }
    SharedWidgetBusyButton {
        visible: root.hasShares
        Layout.fillWidth: true
        text: "Save sharing"
        busyText: "Saving..."
        primary: true
        busy: root.controller.submitting
        enabled: root.controller.fresh && !root.controller.busy && Model.removedShares(root.controller.originalShareIds, root.controller.draft.ids || []).length > 0
        onClicked: root.controller.submit()
    }
}
