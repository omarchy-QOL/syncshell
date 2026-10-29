import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets
import "UiConstants.js" as UiConstants

ColumnLayout {
    id: root
    required property var controller
    function focusFirst() {
        nameField.forceActiveFocus();
    }
    spacing: Theme.spacingS
    BodyFormHeader {
        Layout.fillWidth: true
        title: "Accept remote device request"
        enabled: !root.controller.submitting
        onCancelled: root.controller.closeForm()
    }
    // Omarchy's rows: label on the left, value on the right.
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingS
        StyledText {
            text: "Name"
            color: Theme.onSurfaceVariant
        }
        DTextField {
            id: nameField
            Layout.fillWidth: true
            implicitHeight: UiConstants.CONTROL_HEIGHT + 4
            topPadding: 2
            bottomPadding: 2
            font.pixelSize: Theme.fontSizeSmall
            text: root.controller.draft.name || ""
            placeholderText: "Optional name"
            enabled: !root.controller.busy
            onTextEdited: root.controller.setDraft("name", text)
        }
    }
    SharedWidgetInfoPair {
        Layout.fillWidth: true
        label: "Observed address"
        value: root.controller.draft.address || ""
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingS
        SharedWidgetInfoPair {
            Layout.fillWidth: true
            label: "Device ID"
            value: root.controller.draft.deviceId || ""
        }
        SharedWidgetIdCopyButton {
            caption: ""
            value: root.controller.draft.deviceId || ""
            helpText: "Copy device ID"
        }
    }
    SharedWidgetBusyButton {
        Layout.fillWidth: true
        text: "Accept remote device connection"
        primary: true
        busy: root.controller.submitting
        enabled: !!root.controller.service && root.controller.service.online
        onClicked: root.controller.submit()
    }
}
