import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var controller
    property var parentPopout: null
    readonly property var device: controller.service ? controller.service.device(controller.draft.deviceId) : null
    function options(confirmed) {
        return controller.originalShareIds.map(id => controller.service.folder(id)).filter(Boolean).filter(f => ["valid", "paused"].includes(Model.remoteShare(f, device || {}, controller.fresh)) === confirmed).map(f => ({
                    value: f.id,
                    label: f.label || f.id,
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
        text: "Existing shares"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }
    SharedWidgetDropdown {
        Layout.fillWidth: true
        multiple: true
        placeholder: "No folders shared"
        parentPopout: root.parentPopout
        options: root.options(true)
        selectedValues: (root.controller.draft.ids || []).filter(id => options.some(o => o.value === id))
        enabled: !root.controller.busy
        onToggled: value => root.controller.toggleDraft(value)
    }
    StyledText {
        Layout.fillWidth: true
        text: "Unconfirmed shares (acceptance pending/device offline)"
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.warning
    }
    SharedWidgetDropdown {
        Layout.fillWidth: true
        multiple: true
        placeholder: "No folders shared"
        parentPopout: root.parentPopout
        options: root.options(false)
        selectedValues: (root.controller.draft.ids || []).filter(id => options.some(o => o.value === id))
        enabled: !root.controller.busy
        onToggled: value => root.controller.toggleDraft(value)
    }
    StyledText {
        Layout.fillWidth: true
        text: "Uncheck folders to remove their shares with this device. Files are kept; newly added shares are not changed."
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }
    SharedWidgetBusyButton {
        Layout.fillWidth: true
        text: "Save sharing"
        primary: true
        busy: root.controller.submitting
        enabled: root.controller.fresh && !root.controller.busy && Model.removedShares(root.controller.originalShareIds, root.controller.draft.ids || []).length > 0
        onClicked: root.controller.submit()
    }
}
