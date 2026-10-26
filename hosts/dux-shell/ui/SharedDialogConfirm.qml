import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../models/PanelModel.js" as Model

// Omarchy's confirmation: confirm first, equal widths, the safe answer
// preselected. DConfirmDialogContent fixes Cancel first, so this composes
// the same DMS controls in Omarchy's order.
FocusScope {
    id: root
    property var controller: null
    readonly property var request: controller ? controller.confirmation : null
    readonly property var target: request ? request.target : ({})
    readonly property string action: request ? request.action : ""
    readonly property var text: Model.confirmText(action, target)
    // 0 confirms, 1 cancels.
    property int selectedButton: 1
    implicitHeight: content.implicitHeight
    focus: true
    function selectCancel() {
        selectedButton = 1;
        cancelButton.forceActiveFocus(Qt.TabFocusReason);
    }
    function activate(button) {
        if (!root.controller || root.controller.busy)
            return;
        if (button === 0)
            root.controller.confirm();
        else
            root.controller.cancelConfirmation();
    }
    Component.onCompleted: selectCancel()
    onRequestChanged: selectCancel()
    Keys.onPressed: event => {
        if (event.isAutoRepeat || controller.busy) {
            event.accepted = true;
            return;
        }
        switch (event.key) {
        case Qt.Key_Escape:
            controller.cancelConfirmation();
            break;
        case Qt.Key_Left:
        case Qt.Key_Right:
            selectedButton = event.key === Qt.Key_Left ? 0 : 1;
            (selectedButton === 0 ? confirmButton : cancelButton).forceActiveFocus(Qt.TabFocusReason);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            activate(selectedButton);
            break;
        default:
            return;
        }
        event.accepted = true;
    }
    Column {
        id: content
        width: parent.width
        spacing: Theme.spacingL
        enabled: !root.controller || !root.controller.busy
        StyledText {
            width: parent.width
            text: root.text.title
            textFormat: Text.PlainText
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Theme.fontWeightMedium
            color: Theme.onSurface
            wrapMode: Text.Wrap
        }
        StyledText {
            width: parent.width
            text: root.text.message
            textFormat: Text.PlainText
            color: Theme.onSurfaceVariant
            wrapMode: Text.Wrap
        }
        Row {
            width: parent.width
            spacing: Theme.spacingS
            DButton {
                id: confirmButton
                width: (parent.width - parent.spacing) / 2
                maximumWidth: width
                text: root.text.confirm
                backgroundColor: root.text.destructive ? Theme.errorContainer : Theme.primary
                textColor: root.text.destructive ? Theme.onErrorContainer : Theme.onPrimary
                KeyNavigation.tab: cancelButton
                onActiveFocusChanged: if (activeFocus)
                    root.selectedButton = 0
                onClicked: root.activate(0)
            }
            DButton {
                id: cancelButton
                width: (parent.width - parent.spacing) / 2
                maximumWidth: width
                text: root.text.cancel
                backgroundColor: Theme.secondaryContainer
                textColor: Theme.onSecondaryContainer
                KeyNavigation.tab: confirmButton
                onActiveFocusChanged: if (activeFocus)
                    root.selectedButton = 1
                onClicked: root.activate(1)
            }
        }
    }
}
