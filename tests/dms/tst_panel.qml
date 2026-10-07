import QtQuick
import QtTest
import "../../hosts/dankmaterialshell/controllers"

TestCase {
    id: test
    name: "DmsPanelBehavior"
    property var controller
    QtObject {
        id: backend
        property var folders: []
        property var devices: []
        property bool online: true
        property var connection: ({
                fresh: true
            })
        property bool busy: false
        property bool refreshing: false
        property bool canControlService: true
        property var lifecycle: ({
                active: false,
                enabled: false
            })
        property var sent: null
        property string actionError: ""
        property string _actionName: ""
        property string _actionTargetId: ""
        property var scanningIds: []
        function scanning(id) {
            return scanningIds.includes(id);
        }
        function scanningFolderIds() {
            return scanningIds;
        }
        property var offers: []
        function pendingFolderOffers() {
            return offers;
        }
        function requestFolderIdSuggestion() {
            return true;
        }
        function addFolder(args) {
            return runAction("folder.add-existing", args);
        }
        function addDevice(id, name) {
            return runAction("device.add", {
                deviceId: id,
                deviceName: name
            });
        }
        signal actionFinished(string action, bool ok, var data, var error)
        function remoteDevices() {
            return devices;
        }
        function shareableDevices() {
            return devices;
        }
        function folder(id) {
            return null;
        }
        function device(id) {
            return null;
        }
        function runAction(action, args) {
            sent = {
                action: action,
                args: args
            };
            busy = true;
            return true;
        }
    }
    Component {
        id: factory
        PanelController {
            service: backend
        }
    }
    function init() {
        backend.connection = {
            fresh: true
        };
        backend.offers = [];
        backend.busy = false;
        backend.sent = null;
        backend.canControlService = true;
        backend.lifecycle = {
            active: false,
            enabled: false
        };
        controller = factory.createObject(test);
    }
    function cleanup() {
        controller.destroy();
    }
    function test_runtime_toggle_preserves_autostart() {
        for (var active of [false, true]) {
            for (var enabled of [false, true]) {
                backend.lifecycle = {
                    active: active,
                    enabled: enabled
                };
                verify(controller.requestServiceToggle(null));
                compare(controller.confirmation.action, active ? "lifecycle.stop" : "lifecycle.start");
                verify(controller.confirm());
                compare(backend.sent.action, active ? "lifecycle.stop" : "lifecycle.start");
                compare(backend.lifecycle.enabled, enabled);
                backend.busy = false;
                backend.actionFinished(backend.sent.action, true, {}, null);
            }
        }
    }
    function test_unauthorized_busy_and_nested_actions_are_blocked() {
        backend.canControlService = false;
        verify(!controller.requestServiceToggle(null));
        backend.canControlService = true;
        backend.busy = true;
        verify(!controller.requestServiceToggle(null));
        backend.busy = false;
        controller.begin("add-device", null, null);
        verify(!controller.requestServiceToggle(null));
        controller.closeForm();
        controller.requestConfirmation("device.remove", {
            id: "one"
        }, null);
        verify(!controller.requestServiceToggle(null));
        compare(controller.confirmation.action, "device.remove");
        compare(backend.sent, null);
    }
    function test_draft_and_confirmation_cannot_be_replaced() {
        verify(controller.begin("add-device", null, null));
        controller.setDraft("name", "keep");
        verify(!controller.begin("add-folder", null, null));
        verify(!controller.requestConfirmation("device.remove", {
            id: "one"
        }, null));
        compare(controller.form, "add-device");
        compare(controller.draft.name, "keep");
        controller.closeForm();
        controller.requestConfirmation("device.remove", {
            id: "one"
        }, null);
        verify(!controller.begin("add-folder", null, null));
        verify(!controller.requestConfirmation("folder.forget", {
            id: "two"
        }, null));
        compare(controller.confirmation.target.id, "one");
    }
    function test_stale_submission_keeps_the_draft() {
        controller.begin("add-device", null, null);
        controller.setDraft("name", "keep");
        backend.connection = {
            fresh: false
        };
        verify(!controller.submit());
        compare(backend.sent, null);
        compare(controller.draft.name, "keep");
        verify(controller.error.includes("stale"));
        controller.closeForm();
        controller.requestConfirmation("device.remove", {
            id: "one"
        }, null);
        verify(!controller.confirm());
        compare(backend.sent, null);
        verify(controller.error.includes("stale"));
    }
    function test_vanished_offer_is_rechecked_before_directory_creation() {
        backend.offers = [
            {
                folderId: "offer",
                deviceId: "peer"
            }
        ];
        controller.begin("add-folder", backend.offers[0], null);
        controller.setDraft("path", "/original");
        verify(controller.submit());
        backend.busy = false;
        backend.actionFinished("folder.add-existing", false, null, {
            code: "path_missing"
        });
        compare(controller.confirmation.target.folderId, "offer");
        backend.offers = [];
        backend.sent = null;
        verify(!controller.confirm());
        compare(backend.sent, null);
        compare(controller.draft.path, "/original");
        verify(controller.error.includes("invitation"));
    }
    function test_late_results_cannot_clear_a_different_draft() {
        controller.begin("add-device", null, null);
        controller.setDraft("name", "original");
        verify(controller.submit());
        verify(!controller.begin("add-folder", null, null));
        verify(!controller.closeForm());
        backend.busy = false;
        backend.actionFinished("device.add", true, {}, null);
        controller.begin("add-device", null, null);
        controller.setDraft("name", "new draft");
        backend.actionFinished("device.add", true, {}, null);
        compare(controller.draft.name, "new draft");
        compare(controller.form, "add-device");
    }
    function test_rescan_feedback_tracks_the_operation_and_target() {
        var folder = {
            id: "a",
            status: {
                state: "idle"
            }
        };
        backend.busy = true;
        backend._actionName = "webui.open";
        verify(!controller.rescanning(folder));
        backend._actionName = "folder.rescan";
        backend._actionTargetId = "other";
        verify(!controller.rescanning(folder));
        backend._actionTargetId = "a";
        verify(controller.rescanning(folder));
        compare(controller.folderStatus(folder), "SCANNING");
        backend.busy = false;
        verify(!controller.rescanning(folder));
        backend.busy = true;
        backend._actionName = "folder.rescan-all";
        backend.scanningIds = [];
        verify(controller.rescanning(folder));
        backend.scanningIds = ["other"];
        verify(!controller.rescanning(folder));
        backend.scanningIds = ["a"];
        verify(controller.rescanning(folder));
        verify(!controller.rescanning({
            id: "a",
            paused: true
        }));
        backend.busy = false;
        verify(!controller.rescanning(folder));
    }
}
