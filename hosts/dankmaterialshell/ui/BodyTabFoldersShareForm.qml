import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

ColumnLayout {
    id: root
    required property var controller
    property var parentPopout: null
    spacing: Theme.spacingS
    BodyFormHeader {
        Layout.fillWidth: true
        title: "Share folder"
        enabled: !root.controller.submitting
        onCancelled: root.controller.closeForm()
    }
    StyledText {
        Layout.fillWidth: true
        text: root.controller.service ? root.controller.service.folderLabel(root.controller.draft.folderId) : ""
        textFormat: Text.PlainText
    }
    SharedWidgetDropdown {
        Layout.fillWidth: true
        multiple: true
        placeholder: "Local only"
        parentPopout: root.parentPopout
        options: root.controller.shareableDeviceOptions
        selectedValues: root.controller.draft.ids || []
        enabled: !root.controller.busy
        onToggled: value => root.controller.toggleDraft(value)
    }
    StyledText {
        Layout.fillWidth: true
        text: "Select the devices that should share this folder. Saving an empty selection makes it local only."
        color: Theme.surfaceVariantText
    }
    SharedWidgetBusyButton {
        Layout.fillWidth: true
        text: "Save sharing"
        busy: root.controller.submitting
        enabled: !!root.controller.service && root.controller.service.online
        onClicked: root.controller.submit()
    }
}
