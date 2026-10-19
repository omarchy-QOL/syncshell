import QtQuick
import QtTest
import "../../hosts/illogical-impulse/models/PanelModel.js" as Model

TestCase {
    name: "IllogicalParityModels"
    function test_detailed_and_stale_status() {
        var folder = {id: "a", paused: false, status: {state: "scanning", needTotalItems: 3, errors: []}};
        compare(Model.folderDisplay(folder, true, false).label, "Scanning and syncing");
        compare(Model.folderDisplay({status: {state: "unknown"}}, true, false).role, "muted");
        folder.status.errors = [{path: "locked", error: "permission denied"}];
        var stale = Model.folderDisplay(folder, false, false);
        compare(stale.label, "Unknown");
        verify(stale.hasErrors);
        compare(Model.diagnostics([folder], false)[0].fresh, false);
        compare(Model.diagnostics([folder], false)[0].shown, 1);
    }
    function test_identity_validation() {
        var own = "AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA";
        verify(Model.deviceValidation("bad", own, []) !== "");
        verify(Model.deviceValidation(own.toLowerCase(), own, []).indexOf("this device") >= 0);
        verify(Model.deviceValidation(own, "OTHER", [{id: own}]).indexOf("already") >= 0);
        compare(Model.deviceValidation(own.toLowerCase(), "OTHER", []), "");
    }
    function test_icon_truth_and_error_totals() {
        compare(Model.iconVariant({phase: "core-unavailable", online: false, lifecycle: {}}), "notify");
        compare(Model.iconVariant({phase: "offline", online: false, lifecycle: {canControl: true, active: false}}), "pause");
        var rows = Model.diagnostics([{id: "f", label: "Files", path: "/one", status: {
            error: "stopped", pullErrors: 8, errors: [{path: "one", error: "locked"}]
        }}], true);
        compare(rows[0].shown, 1);
        compare(rows[0].total, 8);
        compare(rows[0].reason, "stopped");
    }
    function test_offer_identity_is_composite() {
        var a = {folderId: "same", deviceId: "one"};
        var b = {folderId: "same", deviceId: "two"};
        verify(Model.offerKey(a) !== Model.offerKey(b));
    }
}
