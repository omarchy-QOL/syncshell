import QtQuick
import Quickshell
import "../hosts/omarchy"
import "../hosts/omarchy/ui"
import "../hosts/omarchy/models/PanelModel.js" as PanelModel

ShellRoot {
    id: root

    property var rows: []
    property int step: 0

    OmarchyPanel {
        id: panel
        function buildFolderRows() {
            return root.rows;
        }
    }

    Item {
        width: 400
        height: 600

        FolderOverview {
            id: overview
            width: parent.width
            controller: panel
            warning: "#ebcb8b"
            success: "#a3be8c"
            syncColor: "#88c0d0"
        }
    }

    function check(condition, message) {
        if (condition)
            return;
        console.error(message);
        Qt.exit(1);
        throw new Error(message);
    }

    function cards() {
        var result = [];
        function visit(item) {
            if (item.folder !== undefined && item.stateLabel !== undefined)
                result.push(item);
            for (var i = 0; i < item.children.length; i++)
                visit(item.children[i]);
        }
        visit(overview);
        return result;
    }

    function selector() {
        for (var i = 0; i < overview.children.length; i++) {
            var child = overview.children[i];
            if (child.options !== undefined)
                return child;
        }
        throw new Error("folder selector missing");
    }

    function folders(count) {
        var configured = [];
        for (var i = 0; i < count; i++) {
            configured.push({
                id: "folder-" + i,
                path: "/tmp/folder-" + i,
                paused: i === 1,
                devices: i === 0 ? [] : [
                    {
                        deviceID: "remote"
                    }
                ]
            });
        }
        return PanelModel.buildFolderRows({
            folders: configured
        }, "/tmp");
    }

    Timer {
        interval: 30
        running: true
        repeat: true
        onTriggered: {
            var picker = root.selector();
            var shown = root.cards();
            switch (root.step++) {
            case 0:
                root.check(shown.length === 0 && !picker.visible, "empty state");
                root.rows = root.folders(1);
                break;
            case 1:
                root.check(shown.length === 1 && !picker.visible, "one folder card");
                root.check(shown[0].folder.sharedDeviceCount === 0, "unshared folder must remain visible");
                root.rows = root.folders(2);
                break;
            case 2:
                root.check(shown.length === 2 && !picker.visible, "two folder cards");
                root.check(shown[1].folder.paused, "paused folder must remain visible");
                root.rows = root.folders(3);
                break;
            case 3:
                root.check(shown.length === 1 && picker.visible, "three folder selector");
                root.check(picker.options.length === 3, "selector includes every folder");
                picker.value = "folder-1";
                picker.changed("folder-1");
                break;
            case 4:
                root.check(shown[0].folder.id === "folder-1", "selection updates card");
                panel.cycleCurrentFolder(1);
                break;
            case 5:
                root.check(picker.value === "folder-2" && shown[0].folder.id === "folder-2", "keyboard selection stays bound");
                root.rows = root.folders(40);
                break;
            case 6:
                root.check(shown.length === 1 && picker.options.length === 40, "large collections retain every option");
                root.check(shown[0].folder.id === "folder-2", "refresh preserves selection");
                root.rows = root.folders(2);
                break;
            case 7:
                root.check(shown.length === 2 && !picker.visible, "return to two cards");
                root.check(panel.currentFolderId === "folder-0", "removed selection falls back");
                root.rows = [];
                break;
            default:
                root.check(shown.length === 0 && panel.currentFolderId === "", "remove last folder");
                console.log("folder overview tests passed");
                Qt.quit();
            }
        }
    }
}
