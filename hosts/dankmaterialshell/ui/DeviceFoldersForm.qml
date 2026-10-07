import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

ColumnLayout {
    id: root
    required property var controller
    property var parentPopout: null
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
    SyncshellDropdown {
        Layout.fillWidth: true
        multiple: true
        placeholder: "No folders shared"
        parentPopout: root.parentPopout
        options: root.controller.originalShareIds.map(function (id) {
            var folder = root.controller.service ? root.controller.service.folder(id) : null;
            return { value: id, label: folder ? folder.label || id : id,
                description: folder ? folder.path : "Folder no longer available" };
        })
        selectedValues: root.controller.draft.ids || []
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
