import QtQuick
import qs.Modals.Common as Native
import "../models/PanelModel.js" as Model

FocusScope {
    id: root
    property var controller: null
    readonly property var request: controller ? controller.confirmation : null
    readonly property var target: request ? request.target : ({})
    readonly property string action: request ? request.action : ""
    readonly property var text: Model.confirmText(action, target)
    implicitHeight: content.implicitHeight
    focus: true
    function selectCancel() {
        content.selectedButton = 0;
        content.keyboardNavigation = true;
        forceActiveFocus();
    }
    Component.onCompleted: selectCancel()
    onRequestChanged: selectCancel()
    Keys.onPressed: event => {
        if (event.isAutoRepeat || controller.busy) {
            event.accepted = true;
            return;
        }
        content.handleKey(event);
    }
    Native.ConfirmDialogContent {
        id: content
        width: parent.width
        enabled: !root.controller || !root.controller.busy
        confirmTitle: root.text.title
        confirmMessage: root.text.message
        onCancelled: root.controller.cancelConfirmation()
        onButtonActivated: button => {
            if (root.controller.busy)
                return;
            if (button === 0)
                root.controller.cancelConfirmation();
            else
                root.controller.confirm();
        }
    }
}
