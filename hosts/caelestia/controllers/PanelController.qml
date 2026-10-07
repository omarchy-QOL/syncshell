pragma ComponentBehavior: Bound

import QtQuick
import "../../../shared/Paths.js" as Paths
import "../models/PanelModel.js" as Model
import "../models/Ownership.js" as Ownership

QtObject {
    id: root
    required property var service
    required property string screenName
    property var view: Model.clone(Ownership.view(screenName, Model.initialView()))
    property string submittedAction: ""
    property var submitted: null
    property string error: view.interrupted ? "An operation was interrupted by reload. Refresh and review before retrying." : ""
    property bool acceptingResults: true
    property bool idSuggestionPending: false
    readonly property var folder: service.folder(view.folderId)
    readonly property var device: service.device(view.deviceId)
    readonly property bool fresh: service.online && service.connection.fresh === true
    readonly property bool busy: !acceptingResults || service.busy || service.refreshing
    readonly property var folderOptions: Model.options(service.folders, "", view.filters, view.sort, fresh, folder => root.folderStatus(folder))
    readonly property var deviceOptions: Model.options(service.remoteDevices(), "", null, "name", fresh)
    property string recentlyLinkedFolderId: ""
    property Timer linkedFeedback: Timer {
        interval: 10000
        onTriggered: root.recentlyLinkedFolderId = ""
    }
    function folderActivity(folder) {
        return Model.folderActivity(folder, fresh, service ? service.currentActivity : null);
    }
    function rescanning(folder) {
        if (!service || !folder || folder.paused || !service.busy)
            return false;
        if (service._actionName === "folder.rescan")
            return service._actionTargetId === folder.id;
        return service._actionName === "folder.rescan-all" && (service.scanning(folder.id) || service.scanningFolderIds().length === 0);
    }
    function folderStatus(folder) {
        return Model.folderStatus(folder, fresh, recentlyLinkedFolderId, !!folderActivity(folder), rescanning(folder));
    }

    signal restoreFocus(string name)

    function retire() {
        if (submittedAction)
            update({
                interrupted: true
            });
        acceptingResults = false;
    }
    function connectionChanged() {
        if (submittedAction || view.form || view.confirmation) {
            submittedAction = "";
            submitted = null;
            update({
                confirmation: null,
                interrupted: true
            });
            error = "The connection changed or an operation was interrupted. Refresh and review your draft before retrying.";
        }
        idSuggestionPending = false;
        recentlyLinkedFolderId = "";
    }
    property Connections coreGeneration: Connections {
        target: root.service ? root.service.core || null : null
        function onGenerationChanged() {
            if (root.acceptingResults)
                root.connectionChanged();
        }
    }
    function update(values) {
        if (!acceptingResults)
            return;
        view = Object.assign({}, view, values);
        Ownership.save(screenName, Model.clone(view));
    }
    function draft(values) {
        if (Object.prototype.hasOwnProperty.call(values, "folderId"))
            idSuggestionPending = false;
        update({
            draft: Object.assign({}, view.draft, values)
        });
    }
    function reconcile() {
        if (view.form === "device-folders" && !submittedAction && !view.confirmation) {
            var current = service.folderIdsForDevice(view.draft.deviceId);
            var original = view.draft.originalFolderIds || [];
            draft({
                folderIds: current.filter(id => !original.includes(id) || view.draft.folderIds.includes(id)),
                originalFolderIds: current.slice()
            });
        }
        update({
            folderId: Model.selectedId(service.folders, view.folderId),
            deviceId: Model.selectedId(service.remoteDevices(), view.deviceId)
        });
    }
    function openForm(kind, target, anchor) {
        if (busy || view.confirmation)
            return;
        if (view.form === kind)
            return;
        if (view.form) {
            error = "Finish or cancel the current form first";
            return;
        }
        error = "";
        var d = {
            folderId: "",
            path: "",
            label: "",
            deviceId: "",
            deviceName: "",
            deviceIds: [],
            folderIds: [],
            pendingDeviceId: ""
        };
        if (kind === "add-folder" && target) {
            if (target.encrypted) {
                service.openWebUi();
                return;
            }
            d.folderId = target.folderId;
            d.label = target.label;
            d.pendingDeviceId = target.deviceId;
            d.deviceIds = [target.deviceId];
        } else if (kind === "share-folder" && target) {
            d.folderId = target.id;
            d.deviceIds = service.remoteDeviceIdsForFolder(target.id);
        } else if (kind === "device-folders" && target) {
            d.deviceId = target.id;
            d.folderIds = service.folderIdsForDevice(target.id);
            d.originalFolderIds = d.folderIds.slice();
        } else if (target) {
            d.deviceId = target.id;
            d.deviceName = target.name || "";
            d.address = target.address || "";
        }
        update({
            form: kind,
            draft: d,
            formAnchor: anchor || 0
        });
        if (kind === "add-folder" && !d.folderId)
            suggestFolderId();
        restoreFocus("form");
    }
    function suggestFolderId() {
        if (busy || submittedAction || view.confirmation || view.form !== "add-folder" || view.draft.pendingDeviceId)
            return false;
        error = "";
        idSuggestionPending = service.requestFolderIdSuggestion();
        if (!idSuggestionPending)
            error = service.actionError || "Could not generate a folder ID";
        return idSuggestionPending;
    }
    function requestServiceToggle() {
        if (busy || submittedAction || view.form || view.confirmation || !service.canControlService)
            return;
        var start = !service.lifecycle.active;
        confirm(start ? "lifecycle.start" : "lifecycle.stop", {}, start ? "Start Syncthing?" : "Stop Syncthing?", "Change the running state of the verified systemd user service. Autostart is unchanged.");
    }
    function cancelForm() {
        if (!acceptingResults || submittedAction)
            return;
        idSuggestionPending = false;
        update({
            form: "",
            draft: {},
            settingsDraft: null,
            confirmation: null,
            picking: false
        });
        error = "";
        restoreFocus("formTrigger");
    }
    function confirm(action, args, title, detail) {
        if (busy || view.confirmation)
            return;
        update({
            confirmation: {
                action: action,
                args: Model.clone(args),
                title: title,
                detail: detail
            }
        });
        restoreFocus("cancel");
    }
    function cancelConfirmation() {
        if (!acceptingResults || submittedAction)
            return;
        update({
            confirmation: null
        });
        reconcile();
        restoreFocus(view.form ? "form" : "main");
    }
    function validTarget(action, args) {
        if (["folder.pause", "folder.resume", "folder.rescan", "folder.forget", "folder.set-sharing"].includes(action) && !service.folder(args.folderId))
            return false;
        if (["device.pause", "device.resume", "device.remove", "device.remove-folder-shares"].includes(action) && !service.device(args.deviceId))
            return false;
        if (action === "folder.add-existing" && args.pendingDeviceId) {
            return service.pendingFolderOffers().some(o => o.folderId === args.folderId && o.deviceId === args.pendingDeviceId && !o.encrypted);
        }
        return true;
    }
    function send(action, args) {
        if (busy || submittedAction)
            return false;
        if (!fresh && !action.startsWith("lifecycle.")) {
            error = "Status is stale; refresh before changing Syncthing";
            return false;
        }
        if (!validTarget(action, args)) {
            error = "The target changed or disappeared; refresh and review it";
            return false;
        }
        update({
            interrupted: false
        });
        submitted = Model.clone(args);
        submittedAction = action;
        error = "";
        if (service.runAction(action, submitted, "Operation completed", args.folderId || args.deviceId || ""))
            return true;
        submittedAction = "";
        submitted = null;
        return false;
    }
    function acceptConfirmation() {
        var c = view.confirmation;
        if (c)
            send(c.action, c.args);
    }
    function submitForm() {
        if (busy || submittedAction || view.confirmation || !view.form)
            return;
        var d = Model.clone(view.draft);
        if (view.form === "add-folder") {
            if (!d.path.trim() || !d.folderId.trim()) {
                error = "Directory and Folder ID are required";
                return;
            }
            send("folder.add-existing", {
                folderId: d.folderId.trim(),
                path: Paths.resolveFolderPath(d.path.trim(), service.homePath),
                label: d.label.trim(),
                deviceIds: d.deviceIds,
                pendingDeviceId: d.pendingDeviceId
            });
        } else if (view.form === "share-folder") {
            confirm("folder.set-sharing", {
                folderId: d.folderId,
                deviceIds: d.deviceIds
            }, "Update folder sharing?", "Review the selected devices. Directory contents are kept.");
        } else if (view.form === "device-folders") {
            var removed = d.originalFolderIds.filter(id => !d.folderIds.includes(id));
            if (!removed.length) {
                error = "Uncheck a folder to remove its share";
                return;
            }
            confirm("device.remove-folder-shares", {
                deviceId: d.deviceId,
                folderIds: removed
            }, "Remove selected shares?", removed.map(id => service.folderLabel(id)).join("\n") + "\nFiles are kept on both devices.");
        } else {
            if (!d.deviceId.trim()) {
                error = "Device ID is required";
                return;
            }
            send("device.add", {
                deviceId: d.deviceId.trim(),
                deviceName: d.deviceName.trim()
            });
        }
    }
    property Connections results: Connections {
        target: root.service
        function onFoldersChanged() {
            root.reconcile();
        }
        function onDevicesChanged() {
            root.reconcile();
        }
        function onActionFinished(action, ok, data, failure) {
            if (!root.acceptingResults)
                return;
            if (action === "folder.suggest-id") {
                var applySuggestion = root.idSuggestionPending && root.view.form === "add-folder" && !root.view.draft.pendingDeviceId;
                root.idSuggestionPending = false;
                if (applySuggestion) {
                    if (ok && data && data.folderId)
                        root.draft({
                            folderId: data.folderId
                        });
                    else
                        root.error = failure && failure.message || "Could not generate a folder ID";
                }
                return;
            }
            if (action !== root.submittedAction)
                return;
            var frozen = root.submitted;
            if (ok && action === "folder.resume") {
                root.recentlyLinkedFolderId = frozen.folderId;
                root.linkedFeedback.restart();
            }
            root.submittedAction = "";
            root.submitted = null;
            if (ok) {
                root.update({
                    confirmation: null
                });
                if (["folder.add-existing", "folder.set-sharing", "device.add", "device.remove-folder-shares"].includes(action))
                    root.cancelForm();
                else
                    root.restoreFocus("main");
            } else if (action === "folder.add-existing" && failure && failure.code === "path_missing") {
                frozen.createDirectory = true;
                root.update({
                    confirmation: null
                });
                root.confirm(action, frozen, "Create this directory?", frozen.path);
            } else {
                root.error = failure && failure.message || "Operation failed";
                root.restoreFocus(root.view.confirmation ? "cancel" : "form");
            }
        }
    }
    Component.onCompleted: reconcile()
}
