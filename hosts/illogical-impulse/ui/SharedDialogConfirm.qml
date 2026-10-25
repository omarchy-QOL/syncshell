import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var style
    required property var controller
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        text: root.controller.confirmation ? root.controller.confirmation.title : ""
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        text: root.controller.confirmation ? root.controller.confirmation.detail : ""
    }
    RowLayout {
        SharedWidgetBusyButton {
            id: cancel
            objectName: "confirmation-cancel"
            style: root.style
            text: "Cancel"
            enabled: !root.controller.pending
            onClicked: root.controller.cancelConfirmation()
        }
        SharedWidgetBusyButton {
            style: root.style
            objectName: "confirmation-submit"
            text: root.controller.confirmation ? root.controller.confirmation.presentation.label : "Confirm"
            busyText: root.controller.confirmation ? root.controller.confirmation.presentation.busy : "Applying"
            tone: root.controller.confirmation && root.controller.confirmation.presentation.destructive ? "danger" : "foreground"
            enabled: !root.controller.blocked
            busy: root.controller.pending
            onClicked: root.controller.confirm(false)
        }
    }
    Component.onCompleted: Qt.callLater(cancel.focusControl)
    Connections {
        target: root.controller
        function onFocusRequested(key) {
            if (key === "cancel-confirm")
                cancel.focusControl();
        }
    }
}
