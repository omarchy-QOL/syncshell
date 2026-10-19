import QtQuick
import QtTest
import "../../hosts/illogical-impulse/controllers" as Controllers
import "../../hosts/illogical-impulse/models/PanelModel.js" as Model

TestCase {
    name: "IllogicalPanelController"
    QtObject {
        id: service
        property var folders: [{id: "a", path: "/one/docs", label: "Alpha", status: {state: "idle"}},
            {id: "b", path: "/two/docs", label: "Beta", status: {state: "syncing"}}]
        property var devices: [{id: "AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA", name: "Remote"}]
        property bool busy: false
        property bool online: true
        property var connection: ({fresh: true})
        property var calls: []
        property var configuredShareIds: ["a", "b"]
        signal actionFinished(string action, bool ok, var data, var error)
        function runAction(action, args) { calls = calls.concat([{action: action, args: Model.clone(args)}]); return true; }
        function folder(id) { return Model.byId(folders, id); }
        function device(id) { return Model.byId(devices, id); }
        function folderArguments(value) { return Model.clone(value); }
        function requestFolderIdSuggestion() { return true; }
        function remoteDeviceIdsForFolder(id) { return ["AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA"]; }
        function folderIdsForDevice(id) { return configuredShareIds.slice(); }
        function deviceName(id) { return id; }
        function folderLabel(id) { return id; }
        function openWebUi() { return runAction("webui.open", {}); }
    }
    Controllers.PanelController { id: panel; service: service }

    function init() {
        panel.preparing = false;
        panel.suggestionGeneration = -1;
        panel.submitted = null;
        panel.confirmation = null;
        panel.discard();
        panel.resetView();
        service.calls = [];
        service.configuredShareIds = ["a", "b"];
    }
    function test_conflicting_draft_requires_explicit_cancel() {
        panel.addFolder(null);
        panel.edit("path", "/tmp/retained");
        panel.formVisible = false;
        verify(!panel.addDevice({id: "new"}, false));
        verify(panel.formVisible);
        compare(panel.view, "add-folder");
        compare(panel.draft.path, "/tmp/retained");
        verify(panel.error.indexOf("existing draft") >= 0);
        panel.error = "";
        verify(!panel.addFolder(null));
        compare(panel.error, "");
    }
    function test_no_op_sharing_and_new_share_reconciliation() {
        panel.deviceFolders(service.devices[0]);
        verify(panel.noSharingChange);
        verify(!panel.save());
        compare(panel.confirmation, null);
        panel.edit("folderIds", []);
        service.configuredShareIds = ["a", "b", "new"];
        panel.reconcileShares();
        compare(panel.draft.folderIds, ["new"]);
        verify(panel.save());
        compare(panel.confirmation.args.folderIds, ["a", "b"]);
    }
    function test_preparation_failure_retry_and_manual_identity() {
        panel.addFolder(null);
        service.actionFinished("folder.suggest-id", false, null, {message: "Preparation failed"});
        verify(!panel.preparing);
        compare(panel.preparationError, "Preparation failed");
        verify(panel.generateFolderId());
        panel.edit("folderId", "manual-id");
        service.actionFinished("folder.suggest-id", true, {folderId: "late"}, null);
        compare(panel.draft.folderId, "manual-id");
        panel.discard();
        panel.addFolder({folderId: "offer", deviceId: "sender", label: "Offered"});
        verify(panel.generateFolderId());
        compare(panel.draft.pendingDeviceId, "");
        service.actionFinished("folder.suggest-id", true, {folderId: "new-id"}, null);
        compare(panel.draft.folderId, "new-id");
    }
    function test_nested_selector_queries_and_dismissal() {
        panel.closeMenus();
        panel.openSelector("outer");
        panel.query = "outer search";
        panel.openSelector("inner");
        panel.query = "inner search";
        panel.handleEscape();
        compare(panel.selector, "outer");
        compare(panel.query, "outer search");
        panel.viewOptionsOpen = true;
        panel.handleEscape();
        verify(!panel.viewOptionsOpen);
        compare(panel.selector, "outer");
        panel.handleEscape();
        compare(panel.selector, "");
        panel.openSelector("inner");
        compare(panel.query, "inner search");
        panel.tab = panel.tab === "folders" ? "devices" : "folders";
        compare(panel.selector, "");
    }
    function test_duplicate_labels_and_sort() {
        var rows = Model.folderOptions(service.folders, true, null, "active", "docs");
        compare(rows[0].id, "b");
        verify(rows[0].label !== rows[1].label);
        compare(Model.folderOptions(service.folders, false, ["unknown"], "name", "").length, 2);
        compare(Model.folderOptions(service.folders, true, ["errors"], "name", "").length, 0);
    }
    function test_hidden_selection_and_mixed_all() {
        compare(Model.allState(["hidden", "a"], ["a", "b"]), "mixed");
        compare(Model.toggleAll(["hidden", "a"], ["a", "b"]), ["hidden", "a", "b"]);
        compare(Model.toggleAll(["hidden", "a", "b"], ["a", "b"]), ["hidden"]);
    }
    function test_draft_survives_close_and_refresh() {
        verify(panel.addFolder(null));
        panel.edit("path", "/tmp/draft");
        panel.edit("folderId", "mine");
        panel.handleEscape();
        verify(!panel.formVisible);
        panel.reopen();
        compare(panel.draft.path, "/tmp/draft");
        service.actionFinished("folder.suggest-id", true, {folderId: "late"}, null);
        compare(panel.draft.folderId, "mine");
        compare(service.calls.length, 0);
        panel.discard();
        compare(panel.view, "");
    }
    function test_missing_directory_freezes_submitted_values() {
        panel.addFolder(null);
        panel.edit("folderId", "new");
        panel.edit("path", "/tmp/original");
        verify(panel.save());
        verify(!panel.save());
        panel.edit("path", "/tmp/blocked-edit");
        compare(panel.draft.path, "/tmp/original");
        service.actionFinished("folder.add-existing", false, null,
            {code: "path_missing", message: "Directory does not exist"});
        verify(panel.confirmation !== null);
        panel.edit("path", "/tmp/later");
        panel.handleEscape();
        panel.reopen();
        verify(!panel.confirm(true));
        verify(panel.confirm(false));
        verify(!panel.confirm(false));
        compare(service.calls.length, 2);
        compare(service.calls[1].args.path, "/tmp/original");
        compare(service.calls[1].args.createDirectory, true);
        service.actionFinished("folder.add-existing", true, {}, null);
        compare(panel.view, "");
    }
    function test_stale_suggestion_and_unrelated_result() {
        panel.addFolder(null);
        panel.discard();
        panel.addDevice({id: "BBBBBBB-BBBBBBB-BBBBBBB-BBBBBBB-BBBBBBB-BBBBBBB-BBBBBBB-BBBBBBB"}, false);
        service.actionFinished("folder.suggest-id", true, {folderId: "late"}, null);
        compare(panel.draft.deviceId, "BBBBBBB-BBBBBBB-BBBBBBB-BBBBBBB-BBBBBBB-BBBBBBB-BBBBBBB-BBBBBBB");
        panel.save();
        service.actionFinished("folder.pause", true, {}, null);
        verify(panel.pending);
        service.actionFinished("device.add", false, null, {message: "offline"});
        verify(!panel.pending);
        compare(panel.error, "offline");
        compare(panel.view, "add-device");
    }
    function test_all_shares_removed_and_frozen() {
        panel.deviceFolders(service.devices[0]);
        panel.edit("folderIds", []);
        verify(panel.save());
        panel.edit("folderIds", ["a"]);
        panel.confirm(false);
        compare(service.calls[0].args.folderIds, ["a", "b"]);
    }
    function test_encrypted_offer_uses_webui() {
        panel.addFolder({folderId: "encrypted", deviceId: "AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA", encrypted: true});
        compare(panel.view, "");
        compare(service.calls[0].action, "webui.open");
    }
    function test_share_refresh_and_confirmation_groups() {
        panel.deviceFolders(service.devices[0]);
        panel.edit("folderIds", ["a"]);
        service.configuredShareIds = ["a", "b", "new"];
        panel.reconcileShares();
        compare(panel.draft.folderIds, ["a", "new"]);
        panel.save();
        compare(panel.confirmation.args.folderIds, ["b"]);
        var folders = ["valid", "paused", "notSharing", "unknown"].map(state =>
            ({id: state, label: state, devices: [{id: "AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA", remoteState: state}]}));
        var peer = {id: "AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA", connected: true, paused: false};
        compare(Model.deviceFolderOptions(folders, peer, true, false).map(row => row.id), ["valid", "paused"]);
        compare(Model.deviceFolderOptions(folders, peer, true, true).map(row => row.id), ["notSharing", "unknown"]);
        compare(Model.deviceFolderOptions(folders, peer, false, true).length, 4);
    }
    function test_vanished_target_and_unrelated_confirmation() {
        panel.shareFolder(service.folders[0]);
        panel.edit("folderId", "vanished");
        verify(panel.targetMissing);
        verify(!panel.save());
        panel.ask("lifecycle.stop", {}, "Stop?", "frozen");
        verify(panel.confirm(false));
        service.actionFinished("lifecycle.stop", true, {}, null);
        compare(panel.view, "share-folder");
        compare(panel.draft.folderId, "vanished");
    }
    function test_empty_many_rows_and_reset() {
        compare(Model.folderOptions([], true, null, "name", ""), []);
        var rows = Array.from({length: 300}, (_, index) => ({id: String(index),
            label: "Folder " + index, path: "/tmp/" + index, status: {state: "idle"}}));
        compare(Model.folderOptions(rows, true, null, "name", "").length, 300);
        compare(Model.folderOptions(rows, true, null, "name", "/tmp/299")[0].id, "299");
        panel.sort = "errors";
        panel.groups = [];
        panel.resetView();
        compare(panel.sort, "name");
        compare(panel.groups.length, 5);
    }
    function test_geometry_all_edges_and_pane_bounds() {
        for (var edge of ["top", "bottom", "left", "right"]) {
            for (var width of [350, 600, 1920]) {
                var height = 900;
                var anchor = {x: edge === "right" ? width - 40 : 0,
                    y: edge === "bottom" ? height - 40 : 0, width: 40, height: 40};
                for (var family of [{width: 440, form: 360}, {width: 410, form: 340}]) {
                    var bounds = Model.geometry(width, height, anchor,
                        {width: family.width, height: 1500},
                        {width: family.form, height: 1200, offset: 600, visible: true}, edge, 10, 12);
                    for (var pane of [bounds.main, bounds.side]) {
                        verify(pane.width > 0 && pane.height > 0);
                        verify(pane.x >= 12 && pane.y >= 12);
                        verify(pane.x + pane.width <= width - 12);
                        verify(pane.y + pane.height <= height - 12);
                    }
                    var a = bounds.main, b = bounds.side;
                    verify(a.x + a.width <= b.x || b.x + b.width <= a.x
                        || a.y + a.height <= b.y || b.y + b.height <= a.y);
                }
            }
        }
    }
    function test_geometry_anchor_and_edge_flip() {
        var a = {x: 1800, y: 0, width: 30, height: 40};
        var first = Model.geometry(1920, 1080, a, {width: 420, height: 600}, {width: 330, height: 480}, "top", 8, 12);
        verify(first.side.x < first.main.x);
        verify(first.main.y >= 48);
        var more = Model.geometry(1920, 1080, a, {width: 420, height: 600}, {width: 330, height: 900}, "top", 8, 12);
        compare(first.main, more.main);
        var narrow = Model.geometry(600, 900, a, {width: 420, height: 300}, {width: 330, height: 280}, "top", 8, 12);
        verify(narrow.stacked);
        verify(narrow.side.x >= 12);
    }
}
