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
        title: "Add folder"
        enabled: !root.controller.submitting
        onCancelled: root.controller.closeForm()
    }
    RowLayout {
        Layout.fillWidth: true
        DankTextField {
            Layout.fillWidth: true
            labelText: "Local directory"
            text: root.controller.draft.path || ""
            placeholderText: "/path/to/my/folder"
            enabled: !root.controller.busy
            onTextEdited: root.controller.setDraft("path", text)
        }
        DankActionButton {
            iconName: "folder_open"
            tooltipText: "Browse for directory"
            enabled: !root.controller.busy
            onClicked: root.controller.directoryPickerRequested()
        }
    }
    DankTextField {
        Layout.fillWidth: true
        labelText: "Label"
        text: root.controller.draft.label || ""
        placeholderText: "Derived from directory when empty"
        enabled: !root.controller.busy
        onTextEdited: root.controller.setDraft("label", text)
    }
    RowLayout {
        Layout.fillWidth: true
        DankTextField {
            Layout.fillWidth: true
            labelText: "Folder ID"
            text: root.controller.draft.folderId || ""
            enabled: !root.controller.busy && !root.controller.draft.pendingDeviceId
            onTextEdited: root.controller.setDraft("folderId", text)
        }
        SharedWidgetSquareActionButton {
            iconName: "refresh"
            help: "Generate a new folder ID"
            enabled: !root.controller.busy && !root.controller.draft.pendingDeviceId
            onClicked: root.controller.suggestFolderId()
        }
    }
    StyledText {
        Layout.fillWidth: true
        text: "Reuse the exact ID to join an existing folder. A new ID creates a different folder identity."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }
    StyledText {
        text: "Share with devices"
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
        text: (root.controller.draft.ids || []).length ? "Only the selected devices will share this folder." : "Local only: not shared with other devices."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }
    SharedWidgetBusyButton {
        Layout.fillWidth: true
        text: "Add folder"
        busy: root.controller.submitting
        enabled: !!root.controller.service && root.controller.service.online && !!root.controller.draft.path && !!root.controller.draft.folderId
        onClicked: root.controller.submit()
    }
}
