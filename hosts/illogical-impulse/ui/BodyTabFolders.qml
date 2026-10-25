import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var style
    required property var controller
    RowLayout {
        Layout.fillWidth: true
        BodyTabFoldersSelector { style: root.style; controller: root.controller; Layout.fillWidth: true }
        SharedWidgetSquareActionButton {
            objectName: "add-folder"
            style: root.style
            text: "Add folder"
            actionIcon: "add"
            help: "Add an existing directory or accept a folder invitation"
            enabled: root.controller.service.online && !root.controller.blocked
            onClicked: source => { root.controller.rememberTrigger(source); root.controller.addFolder(null); }
        }
    }
    RowLayout {
        visible: root.controller.folder !== null
        SharedWidgetBusyButton {
            objectName: "share-folder"
            style: root.style
            text: "Share"
            help: "Choose remote devices; clear every selection for local-only synchronization"
            enabled: root.controller.service.online && !root.controller.blocked
            onClicked: source => { root.controller.rememberTrigger(source); root.controller.shareFolder(root.controller.folder); }
        }
        SharedWidgetBusyButton {
            objectName: "folder-pause"
            style: root.style
            text: root.controller.folder && root.controller.folder.paused ? "Resume" : "Pause"
            enabled: root.controller.service.online && !root.controller.blocked
            onClicked: source => {
                root.controller.rememberTrigger(source);
                var folder = root.controller.folder;
                root.controller.ask(folder.paused ? "folder.resume" : "folder.pause", {folderId: folder.id},
                    (folder.paused ? "Resume " : "Pause ") + (folder.label || folder.id) + "?", folder.path);
            }
        }
        SharedWidgetNativeText { style: root.style; Layout.fillWidth: true; muted: true; text: root.controller.folderRows.length + " of " + root.controller.service.folders.length + " folders" }
    }
    Loader {
        Layout.fillWidth: true
        active: root.controller.folder !== null
        sourceComponent: BodyTabFoldersCard { style: root.style; controller: root.controller; folder: root.controller.folder }
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        visible: !root.controller.folder
        text: "No folders configured. Add an existing directory or accept an invitation."
    }
}
