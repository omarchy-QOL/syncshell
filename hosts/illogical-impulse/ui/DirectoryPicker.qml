import QtQuick
import QtQuick.Dialogs
import "../../../shared/Paths.js" as Paths

FolderDialog {
    id: root
    required property var controller
    property int draftGeneration: -1
    signal opening
    signal returned
    title: "Choose synchronization directory"
    options: FolderDialog.DontUseNativeDialog
    function pick() {
        if (controller.blocked || controller.view !== "add-folder") return;
        draftGeneration = controller.draftGeneration;
        opening();
        open();
    }
    function finish() {
        returned();
        Qt.callLater(() => controller.focusRequested("first-field"));
    }
    onAccepted: {
        if (controller.draftGeneration === draftGeneration && controller.view === "add-folder")
            controller.edit("path", Paths.localFilePath(selectedFolder));
        finish();
    }
    onRejected: finish()
    property Connections requests: Connections {
        target: root.controller
        function onBrowseRequested() { root.pick(); }
    }
}
