import QtQuick
import qs.Modals.Common as Native

FocusScope {
    id: root
    property var controller: null
    readonly property var request: controller ? controller.confirmation : null
    readonly property var target: request ? request.target : ({})
    readonly property string action: request ? request.action : ""
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
        confirmTitle: root.action === "folder.add-existing" ? "Create directory?" : root.action === "folder.forget" ? "Forget folder?" : root.action === "device.remove" ? "Remove device?" : root.action.indexOf("lifecycle.") === 0 ? "Change Syncthing service?" : "Dismiss invitation?"
        confirmMessage: root.action === "folder.add-existing" ? "Create " + root.target.path + " and add it to Syncthing?" : root.action === "folder.forget" ? "Forget " + (root.target.label || root.target.id) + "? Its files will be kept." : root.action === "device.remove" ? "Remove " + (root.target.name || root.target.id) + " and its folder shares? Files will be kept." : root.action.indexOf("lifecycle.") === 0 ? "This changes the authorized systemd user service for this Syncthing instance." : "Dismiss this invitation from " + (root.target.name || root.target.deviceId || root.target.id) + "?"
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
