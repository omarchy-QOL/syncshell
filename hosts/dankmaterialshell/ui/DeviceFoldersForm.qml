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
                    description: f.path,
                    status: Model.remoteShare(f, device || {}, controller.fresh)
                }));
    }
    spacing: Theme.spacingS
    InlineFormHeader {
        Layout.fillWidth: true
        title: "Shared folders"
        enabled: !root.controller.submitting
        onCancelled: root.controller.closeForm()
    }
    StyledText {
        Layout.fillWidth: true
        text: root.controller.draft.name || root.controller.draft.deviceId || ""
        textFormat: Text.PlainText
    }
    StyledText {
        text: "Existing shares"
    }
    SyncshellDropdown {
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
        color: Theme.surfaceVariantText
    }
    SyncshellDropdown {
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
        color: Theme.surfaceVariantText
    }
    BusyButton {
        Layout.fillWidth: true
        text: "Save shares"
        busy: root.controller.submitting
        enabled: !!root.controller.service && root.controller.service.online
        onClicked: root.controller.submit()
    }
}
