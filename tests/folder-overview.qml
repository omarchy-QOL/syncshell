import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons
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

    Window {
        visible: true
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

    function viewRows(errorResolved) {
        var configured = [
            {
                id: "ready",
                path: "/tmp/alpha",
                devices: []
            },
            {
                id: "active",
                path: "/tmp/beta",
                devices: []
            },
            {
                id: "errors",
                path: "/tmp/gamma",
                devices: []
            },
            {
                id: "paused",
                path: "/tmp/delta",
                paused: true,
                devices: []
            }
        ];
        var statuses = {
            ready: {
                state: "idle"
            },
            active: {
                state: "syncing",
                needTotalItems: 2
            },
            errors: errorResolved ? {
                state: "idle"
            } : {
                state: "error",
                error: "boom",
                errors: 1
            },
            paused: {
                state: "idle"
            }
        };
        return PanelModel.buildFolderRows({
            folders: configured,
            folderStatuses: statuses
        }, "/tmp");
    }

    function optionByValue(options, value) {
        for (var i = 0; i < options.length; i++) {
            if (options[i].value === value)
                return options[i];
        }
        return null;
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
                root.rows = root.viewRows(false);
                break;
            case 8:
                var initial = panel.folderViewOptions();
                root.check(shown.length === 1 && picker.visible, "view rows use selector");
                root.check(initial.length === 4, "default view includes every folder");
                root.check(!picker.statusVisible, "selector trigger omits the redundant folder status");
                root.check(root.optionByValue(initial, "ready").statusVisible, "selector results retain folder statuses");
                root.check(root.optionByValue(initial, "ready").group === "ready" && root.optionByValue(initial, "active").group === "active" && root.optionByValue(initial, "errors").group === "errors" && root.optionByValue(initial, "paused").group === "paused", "badge states map to exclusive groups");
                root.check(PanelModel.folderStateGroup("UNKNOWN") === "unknown" && PanelModel.folderStateHelpText("SCAN+SYNC") === "SCAN+SYNC · Rescanning and syncing", "state metadata");
                root.check(String(panel.folderStateColor(null)) === String(Color.muted), "unknown state uses theme muted");
                picker.open();
                picker.headerAccessoryItem.toggle();
                break;
            case 9:
                root.check(picker.popupOpen && picker.headerAccessoryOpen, "folder view options open inside the selector");
                root.check(picker.headerAccessoryItem.resultCount === 4 && picker.headerAccessoryItem.totalCount === 4, "view options receive result counts");
                picker.headerAccessoryItem.activateFilter("ready");
                root.check(!panel.folderShowReady, "filter controls apply immediately");
                picker.headerAccessoryItem.activateFilter("all");
                root.check(panel.folderShowReady && panel.folderShowActive && panel.folderShowErrors && panel.folderShowPaused && panel.folderShowUnknown, "all restores every filter");
                picker.headerAccessoryItem.close();
                picker.close();
                panel.setAllFolderGroups(false);
                panel.setFolderGroupVisible("errors", true);
                panel.setFolderGroupVisible("paused", true);
                break;
            case 10:
                root.check(picker.options.length === 2 && picker.options[0].value === "paused" && picker.options[1].value === "errors", "filters combine with OR");
                root.check(picker.headerAccessoryItem.resultCount === 2, "result count follows filters");
                root.check(panel.currentFolderId === "ready" && shown[0].folder.id === "ready", "filtering preserves a nonmatching selection");
                root.check(picker.currentText === "alpha", "filtered selection keeps its trigger label");
                root.rows = root.viewRows(true);
                break;
            case 11:
                root.check(picker.options.length === 1 && picker.options[0].value === "paused", "resolved error leaves the filtered list");
                root.check(panel.currentFolderId === "ready", "live filtering does not switch the card");
                panel.setFolderGroupVisible("paused", false);
                break;
            case 12:
                root.check(picker.options.length === 0, "empty filtered results");
                panel.resetFolderView();
                panel.folderSortMode = "active";
                break;
            case 13:
                root.check(picker.options[0].value === "active", "active sort prioritizes live work");
                root.rows = root.viewRows(false);
                panel.folderSortMode = "errors";
                break;
            case 14:
                root.check(picker.options[0].value === "errors", "error sort prioritizes attention");
                root.check(picker.options[1].label === "alpha" && picker.options[2].label === "beta" && picker.options[3].label === "delta", "priority ties remain alphabetical");
                panel.folderShowReady = false;
                panel.folderSortMode = "active";
                panel.resetTransientState();
                break;
            case 15:
                root.check(!panel.folderShowReady && panel.folderSortMode === "active", "view choices survive transient reset");
                panel.resetFolderView();
                break;
            case 16:
                root.check(panel.folderShowReady && panel.folderShowActive && panel.folderShowErrors && panel.folderShowPaused && panel.folderShowUnknown && panel.folderSortMode === "name", "reset restores folder view defaults");
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
