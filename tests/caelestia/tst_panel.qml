import QtQuick
import QtTest
import "../../hosts/caelestia/controllers"

TestCase {
    id: test
    name: "CaelestiaPanelBehavior"
    property var controller
    QtObject {
        id: backend
        property var folders: [
            {
                id: "a",
                label: "same"
            },
            {
                id: "b",
                label: "same"
            }
        ]
        property var devices: [
            {
                id: "one"
            },
            {
                id: "two"
            }
        ]
        property var sharedFolders: ["a", "b"]
        property var pendingDevices: []
        property var offers: []
        property QtObject core: QtObject {
            property int generation: 1
        }
        property bool online: true
        property var connection: ({
                fresh: true
            })
        property bool busy: false
        property bool refreshing: false
        property string homePath: "/home/test"
        property var sent: null
        signal actionFinished(string action, bool ok, var data, var error)
        function remoteDevices() {
            return devices;
        }
        function folder(id) {
            return folders.find(f => f.id === id) || null;
        }
        function device(id) {
            return devices.find(d => d.id === id) || null;
        }
        function pendingFolderOffers() {
            return offers;
        }
        function folderIdsForDevice(id) {
            return sharedFolders;
        }
        function remoteDeviceIdsForFolder(id) {
            return ["one"];
        }
        function folderLabel(id) {
            return id;
        }
        property bool canControlService: true
        property var lifecycle: ({
                active: false,
                enabled: false
            })
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
        function requestFolderIdSuggestion() {
            busy = true;
            return true;
        }
        function runAction(action, args) {
            sent = {
                action: action,
                args: JSON.parse(JSON.stringify(args))
            };
            busy = true;
            return true;
        }
    }
    Component {
        id: factory
        PanelController {
            service: backend
            screenName: "test"
        }
    }
    function init() {
        backend.folders = [
            {
                id: "a",
                label: "same"
            },
            {
                id: "b",
                label: "same"
            }
        ];
        backend.pendingDevices = [];
        backend.offers = [];
        backend.canControlService = true;
        backend.lifecycle = {
            active: false,
            enabled: false
        };
        backend.busy = false;
        backend.sent = null;
        backend.sharedFolders = ["a", "b"];
        backend.connection = {
            fresh: true
        };
        controller = factory.createObject(test);
        controller.update({
            form: "",
            draft: {},
            confirmation: null,
            folderId: "a"
        });
    }
    function cleanup() {
        controller.destroy();
    }
    function test_vanished_device_invitation_preserves_accept_draft() {
        backend.pendingDevices = [
            {
                id: "peer",
                name: "Invited"
            }
        ];
        controller.openForm("accept-device", backend.pendingDevices[0], 0);
        controller.draft({
            deviceName: "My name"
        });
        backend.pendingDevices = [
            {
                id: "another"
            }
        ];
        controller.submitForm();
        compare(backend.sent, null);
        compare(controller.view.draft.deviceId, "peer");
        compare(controller.view.draft.deviceName, "My name");
        verify(controller.error.includes("invitation"));
        compare(controller.submittedAction, "");
    }
    function test_vanished_invitation_cannot_be_dismissed() {
        for (var folder of [false, true]) {
            backend.pendingDevices = [
                {
                    id: "peer"
                }
            ];
            backend.offers = [
                {
                    folderId: "offered",
                    deviceId: "peer",
                    encrypted: true
                }
            ];
            controller.confirm(folder ? "folder.dismiss-pending" : "device.dismiss-pending", folder ? {
                folderId: "offered",
                pendingDeviceId: "peer"
            } : {
                deviceId: "peer"
            }, "Dismiss?", "");
            backend.pendingDevices = [
                {
                    id: "another"
                }
            ];
            backend.offers = [
                {
                    folderId: "offered",
                    deviceId: "another"
                }
            ];
            controller.acceptConfirmation();
            compare(backend.sent, null);
            verify(controller.error.includes("invitation"));
            controller.cancelConfirmation();
        }
    }
    function test_live_invitation_keeps_its_frozen_target() {
        for (var folder of [false, true]) {
            backend.pendingDevices = [
                {
                    id: "peer"
                },
                {
                    id: "another"
                }
            ];
            backend.offers = [
                {
                    folderId: "offered",
                    deviceId: "peer",
                    encrypted: true
                }
            ];
            var args = folder ? {
                folderId: "offered",
                pendingDeviceId: "peer"
            } : {
                deviceId: "peer"
            };
            controller.confirm(folder ? "folder.dismiss-pending" : "device.dismiss-pending", args, "Dismiss?", "");
            args.deviceId = "another";
            args.pendingDeviceId = "another";
            controller.acceptConfirmation();
            compare(backend.sent.args[folder ? "pendingDeviceId" : "deviceId"], "peer");
            backend.busy = false;
            backend.actionFinished(backend.sent.action, true, {}, null);
        }
        controller.openForm("accept-device", backend.pendingDevices[0], 0);
        controller.submitForm();
        compare(backend.sent.action, "device.add");
        compare(backend.sent.args.deviceId, "peer");
    }
    function test_closed_form_cannot_submit() {
        controller.submitForm();
        compare(backend.sent, null);
        compare(controller.submittedAction, "");
    }
    function test_retired_controller_cannot_write_or_dispatch() {
        controller.openForm("add-device", null, 0);
        controller.draft({
            deviceId: "old"
        });
        controller.retire();
        var replacement = factory.createObject(test);
        replacement.draft({
            deviceId: "new"
        });
        controller.draft({
            deviceId: "late"
        });
        controller.cancelForm();
        controller.submitForm();
        verify(!controller.send("device.add", {
            deviceId: "late"
        }));
        compare(backend.sent, null);
        replacement.retire();
        replacement.destroy();
        var reopened = factory.createObject(test);
        compare(reopened.view.form, "add-device");
        compare(reopened.view.draft.deviceId, "new");
        reopened.destroy();
    }
    function test_stable_selection_and_draft() {
        controller.update({
            folderId: "b"
        });
        controller.openForm("add-folder", null, 20);
        controller.draft({
            path: "~/work",
            folderId: "new",
            label: "draft"
        });
        backend.folders = [
            {
                id: "b",
                label: "renamed"
            },
            {
                id: "a",
                label: "same"
            }
        ];
        compare(controller.view.folderId, "b");
        compare(controller.view.draft.label, "draft");
        controller.destroy();
        controller = factory.createObject(test);
        compare(controller.view.draft.path, "~/work");
    }
    function test_frozen_confirmation_and_duplicate_submit() {
        controller.confirm("folder.forget", {
            folderId: "b"
        }, "Forget?", "keep files");
        controller.update({
            folderId: "a"
        });
        controller.acceptConfirmation();
        compare(backend.sent.args.folderId, "b");
        controller.acceptConfirmation();
        compare(controller.submittedAction, "folder.forget");
        backend.busy = false;
        backend.actionFinished("folder.forget", true, {}, null);
        compare(controller.view.confirmation, null);
        compare(controller.submittedAction, "");
    }
    function test_missing_directory_requires_frozen_confirmation() {
        controller.openForm("add-folder", null, 0);
        backend.busy = false;
        backend.actionFinished("folder.suggest-id", true, {
            folderId: "suggested"
        }, null);
        controller.draft({
            path: "~/work",
            folderId: "new",
            label: "original"
        });
        controller.submitForm();
        compare(backend.sent.args.path, "/home/test/work");
        backend.busy = false;
        backend.actionFinished("folder.add-existing", false, null, {
            code: "path_missing",
            message: "missing"
        });
        compare(controller.view.confirmation.args.createDirectory, true);
        controller.draft({
            path: "/changed"
        });
        controller.acceptConfirmation();
        compare(backend.sent.args.path, "/home/test/work");
    }
    function test_vanished_target_is_rejected() {
        controller.confirm("folder.forget", {
            folderId: "b"
        }, "Forget?", "keep files");
        backend.folders = [
            {
                id: "a"
            }
        ];
        controller.acceptConfirmation();
        compare(backend.sent, null);
        verify(controller.error.includes("disappeared"));
    }
    function test_new_shares_are_kept_during_a_draft() {
        controller.openForm("device-folders", {
            id: "one"
        }, 0);
        controller.draft({
            folderIds: ["b"]
        });
        backend.sharedFolders = ["a", "b", "new"];
        backend.folders = backend.folders.concat([
            {
                id: "new"
            }
        ]);
        compare(controller.view.draft.folderIds.join(","), "b,new");
        controller.submitForm();
        controller.acceptConfirmation();
        compare(backend.sent.args.folderIds.join(","), "a");
    }
    function test_stale_confirmation_is_not_submitted() {
        controller.confirm("folder.forget", {
            folderId: "a"
        }, "Forget?", "keep files");
        backend.connection = {
            fresh: false
        };
        controller.acceptConfirmation();
        compare(backend.sent, null);
        verify(controller.error.includes("stale"));
    }
    function test_cancel_discards_settings_draft() {
        controller.openForm("settings", null, 0);
        controller.update({
            settingsDraft: {
                probeSeconds: 37
            }
        });
        controller.cancelForm();
        compare(controller.view.settingsDraft, null);
        compare(controller.view.form, "");
    }
    function test_success_restores_form_trigger() {
        var destinations = [];
        controller.restoreFocus.connect(name => destinations.push(name));
        controller.openForm("add-device", null, 0);
        controller.draft({
            deviceId: "new",
            deviceName: "name"
        });
        controller.submitForm();
        backend.busy = false;
        backend.actionFinished("device.add", true, {}, null);
        compare(controller.view.form, "");
        compare(destinations[destinations.length - 1], "formTrigger");
    }
    function test_failed_action_retains_draft() {
        controller.openForm("add-device", null, 0);
        controller.draft({
            deviceId: "new",
            deviceName: "name"
        });
        controller.submitForm();
        backend.busy = false;
        backend.actionFinished("device.add", false, null, {
            message: "offline"
        });
        compare(controller.view.form, "add-device");
        compare(controller.view.draft.deviceName, "name");
        compare(controller.error, "offline");
    }
    function test_service_toggle_preserves_autostart() {
        for (var active of [false, true]) {
            for (var enabled of [false, true]) {
                backend.lifecycle = {
                    active: active,
                    enabled: enabled
                };
                controller.requestServiceToggle();
                compare(controller.view.confirmation.action, active ? "lifecycle.stop" : "lifecycle.start");
                controller.acceptConfirmation();
                compare(backend.sent.action, active ? "lifecycle.stop" : "lifecycle.start");
                compare(backend.lifecycle.enabled, enabled);
                backend.busy = false;
                backend.actionFinished(backend.sent.action, true, {}, null);
            }
        }
        backend.sent = null;
        backend.canControlService = false;
        controller.requestServiceToggle();
        compare(controller.view.confirmation, null);
        compare(backend.sent, null);
    }
    function test_service_toggle_does_not_replace_a_draft() {
        controller.openForm("add-device", null, 0);
        controller.requestServiceToggle();
        compare(controller.view.confirmation, null);
        controller.cancelForm();
        controller.confirm("folder.forget", {
            folderId: "a"
        }, "Forget?", "kept");
        controller.requestServiceToggle();
        compare(controller.view.confirmation.action, "folder.forget");
    }
    function test_explicit_folder_id_replaces_existing_id() {
        controller.openForm("add-folder", null, 0);
        backend.busy = false;
        backend.actionFinished("folder.suggest-id", true, {
            folderId: "first"
        }, null);
        compare(controller.view.draft.folderId, "first");
        verify(controller.suggestFolderId());
        compare(controller.view.draft.folderId, "first");
        backend.busy = false;
        backend.actionFinished("folder.suggest-id", true, {
            folderId: "second"
        }, null);
        compare(controller.view.draft.folderId, "second");
        verify(controller.suggestFolderId());
        backend.busy = false;
        backend.actionFinished("folder.suggest-id", false, null, {
            message: "offline"
        });
        compare(controller.view.draft.folderId, "second");
        compare(controller.error, "offline");
    }
    function test_late_suggestion_preserves_typing_and_cancel() {
        controller.openForm("add-folder", null, 0);
        controller.draft({
            folderId: "typed"
        });
        backend.busy = false;
        backend.actionFinished("folder.suggest-id", true, {
            folderId: "late"
        }, null);
        compare(controller.view.draft.folderId, "typed");
        verify(controller.suggestFolderId());
        controller.cancelForm();
        backend.busy = false;
        backend.actionFinished("folder.suggest-id", true, {
            folderId: "late"
        }, null);
        compare(controller.view.form, "");
        compare(controller.view.draft.folderId, undefined);
    }
    function test_pending_offer_identity_cannot_be_regenerated() {
        controller.openForm("add-folder", {
            folderId: "exact",
            deviceId: "one"
        }, 0);
        verify(!controller.suggestFolderId());
        backend.actionFinished("folder.suggest-id", true, {
            folderId: "wrong"
        }, null);
        compare(controller.view.draft.folderId, "exact");
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
    function test_restart_drops_the_old_confirmation_and_keeps_input() {
        controller.openForm("add-folder", null, 0);
        backend.busy = false;
        controller.draft({
            folderId: "id",
            path: "/keep"
        });
        controller.submitForm();
        backend.busy = false;
        backend.actionFinished("folder.add-existing", false, null, {
            code: "path_missing"
        });
        verify(!!controller.view.confirmation);
        backend.core.generation++;
        compare(controller.view.confirmation, null);
        compare(controller.view.draft.path, "/keep");
        compare(controller.submittedAction, "");
        verify(controller.view.interrupted);
        verify(controller.error.includes("connection changed"));
    }
    function test_required_fields_reject_whitespace_without_losing_input() {
        controller.openForm("add-folder", null, 0);
        backend.busy = false;
        controller.draft({
            folderId: "id",
            path: "   "
        });
        controller.submitForm();
        compare(backend.sent, null);
        compare(controller.view.draft.path, "   ");
        verify(controller.error.includes("required"));
        controller.cancelForm();
        controller.openForm("add-device", null, 0);
        controller.draft({
            deviceId: "   "
        });
        controller.submitForm();
        compare(backend.sent, null);
        verify(controller.error.includes("required"));
    }
    function test_backend_rejections_preserve_input_and_do_not_confirm_creation() {
        for (var failure of [
            {
                code: "path_invalid",
                message: "folder path must be a directory"
            },
            {
                code: "path_overlap",
                message: "folder path overlaps a configured folder"
            },
            {
                code: "folder_exists",
                message: "folder is already configured"
            }
        ]) {
            controller.openForm("add-folder", null, 0);
            backend.busy = false;
            controller.draft({
                folderId: "id",
                path: "/keep"
            });
            controller.submitForm();
            backend.busy = false;
            backend.actionFinished("folder.add-existing", false, null, failure);
            compare(controller.view.confirmation, null);
            compare(controller.view.draft.path, "/keep");
            compare(controller.error, failure.message);
            controller.cancelForm();
        }
        for (var failure of [
            {
                code: "device_id_invalid",
                message: "device ID is invalid"
            },
            {
                code: "device_self",
                message: "this device cannot be added as a remote device"
            },
            {
                code: "device_exists",
                message: "device is already configured"
            }
        ]) {
            controller.openForm("add-device", null, 0);
            controller.draft({
                deviceId: "input",
                deviceName: "keep"
            });
            controller.submitForm();
            backend.busy = false;
            backend.actionFinished("device.add", false, null, failure);
            compare(controller.view.draft.deviceId, "input");
            compare(controller.view.draft.deviceName, "keep");
            compare(controller.error, failure.message);
            controller.cancelForm();
        }
    }
}
