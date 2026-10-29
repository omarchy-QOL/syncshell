import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets
import "UiConstants.js" as UiConstants

ColumnLayout {
    id: root
    required property var controller
    property var parentPopout: null
    function focusFirst() {
        pathField.forceActiveFocus();
    }
    spacing: Theme.spacingS
    BodyFormHeader {
        Layout.fillWidth: true
        title: "Add folder"
        enabled: !root.controller.submitting
        onCancelled: root.controller.closeForm()
    }
    StyledText {
        text: "Local directory"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.onSurfaceVariant
    }
    RowLayout {
        Layout.fillWidth: true
        DTextField {
            id: pathField
            Layout.fillWidth: true
            implicitHeight: UiConstants.CONTROL_HEIGHT + 4
            topPadding: 2
            bottomPadding: 2
            font.pixelSize: Theme.fontSizeSmall
            text: root.controller.draft.path || ""
            placeholderText: "/path/to/my/folder"
            enabled: !root.controller.busy
            onTextEdited: root.controller.setDraft("path", text)
        }
        SharedWidgetSquareActionButton {
            iconName: "folder_open"
            help: "Browse for directory"
            enabled: !root.controller.busy
            onClicked: root.controller.directoryPickerRequested()
        }
    }
    StyledText {
        text: "Label"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.onSurfaceVariant
    }
    DTextField {
        Layout.fillWidth: true
        implicitHeight: UiConstants.CONTROL_HEIGHT + 4
        topPadding: 2
        bottomPadding: 2
        font.pixelSize: Theme.fontSizeSmall
        text: root.controller.draft.label || ""
        placeholderText: "Derived from the directory name when empty"
        enabled: !root.controller.busy
        onTextEdited: root.controller.setDraft("label", text)
    }
    StyledText {
        text: "Folder ID"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.onSurfaceVariant
    }
    RowLayout {
        Layout.fillWidth: true
        DTextField {
            Layout.fillWidth: true
            implicitHeight: UiConstants.CONTROL_HEIGHT + 4
            topPadding: 2
            bottomPadding: 2
            font.pixelSize: Theme.fontSizeSmall
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
        text: "Reuse the exact ID to rejoin an existing remote folder. A new ID creates a different folder identity."
        color: Theme.onSurfaceVariant
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }
    StyledText {
        text: "Share with devices"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.onSurfaceVariant
    }
    SharedWidgetMultiSelect {
        Layout.fillWidth: true
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
        color: Theme.onSurfaceVariant
        font.pixelSize: Theme.fontSizeSmall
    }
    SharedWidgetBusyButton {
        Layout.fillWidth: true
        text: "Add folder"
        primary: true
        busy: root.controller.submitting
        enabled: !!root.controller.service && root.controller.service.online && !!root.controller.draft.path && !!root.controller.draft.folderId
        onClicked: root.controller.submit()
    }
}
