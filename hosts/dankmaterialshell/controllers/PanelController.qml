import QtQuick
import "../models/PanelModel.js" as Model

QtObject {
    id: root

    property var service: null
    property string tab: "folders"
    property string selectedFolderId: ""
    property string selectedDeviceId: ""
    property var groups: ["ready", "active", "errors", "paused", "unknown"]
    property string sort: "name"
    property bool moreOpen: false
    property string form: ""
    property var draft: ({})
    property var originalShareIds: []
    property var confirmation: null
    property bool submitting: false
    property string pendingAction: ""
    property var submittedDraft: null
    property string error: ""
    property var returnFocus: null

    readonly property var folder: service ? service.folder(selectedFolderId) : null
    readonly property var device: service ? service.device(selectedDeviceId) : null
    readonly property bool fresh: !!service && service.online && service.connection.fresh === true
    readonly property var folderOptions: Model.folderOptions(service ? service.folders : [], fresh, groups, sort, folder => root.folderStatus(folder))
    readonly property var deviceOptions: Model.deviceOptions(service ? service.remoteDevices() : [], fresh)
    readonly property var shareableDeviceOptions: Model.deviceOptions(service ? service.shareableDevices() : [], fresh)
    readonly property bool busy: submitting || !!service && (service.busy || service.refreshing)

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

    signal focusRequested(var target)
    signal directoryPickerRequested

    function reconcile() {
        if (!service)
            return;
        if (form === "device-folders" && !submitting && !confirmation) {
            var current = service.folderIdsForDevice(draft.deviceId);
            setDraft("ids", current.filter(id => originalShareIds.indexOf(id) < 0 || draft.ids.indexOf(id) >= 0));
            originalShareIds = current.slice();
        }
        selectedFolderId = Model.retainedSelection(service.folders, selectedFolderId);
        selectedDeviceId = Model.retainedSelection(service.remoteDevices(), selectedDeviceId);
    }

    property string linkingFolderId: ""
    function toggleFolder() {
        if (!folder || !fresh || busy || confirmation || form)
            return false;
        linkingFolderId = folder.paused ? folder.id : "";
        var accepted = service.setFolderPaused(folder.id, !folder.paused);
        if (!accepted)
            linkingFolderId = "";
        return accepted;
    }
    function resetFilters() {
        groups = ["ready", "active", "errors", "paused", "unknown"];
        sort = "name";
    }

    function toggleGroup(group) {
        groups = Model.toggled(groups, group);
    }

    function setDraft(key, value) {
        var next = Object.assign({}, draft);
        next[key] = value;
        draft = next;
    }

    function toggleDraft(id) {
        setDraft("ids", Model.toggled(draft.ids || [], id));
    }

    function begin(nextForm, value, trigger) {
        if (busy)
            return false;
        var target = value || {};
        error = "";
        confirmation = null;
        returnFocus = trigger || null;
        originalShareIds = [];
        if (nextForm === "add-folder") {
            draft = {
                path: "",
                label: String(target.label || ""),
                folderId: String(target.folderId || ""),
                pendingDeviceId: String(target.deviceId || ""),
                ids: target.deviceId ? [target.deviceId] : []
            };
        } else if (nextForm === "add-device" || nextForm === "accept-device") {
            draft = {
                deviceId: String(target.id || ""),
                name: String(target.name || ""),
                address: String(target.address || "")
            };
        } else if (nextForm === "share-folder") {
            if (!service || !service.folder(target.id))
                return false;
            draft = {
                folderId: target.id,
                ids: service.remoteDeviceIdsForFolder(target.id).slice()
            };
        } else if (nextForm === "device-folders") {
            if (!service || !service.device(target.id))
                return false;
            originalShareIds = service.folderIdsForDevice(target.id).slice();
            draft = {
                deviceId: target.id,
                name: target.name,
                ids: originalShareIds.slice()
            };
        } else {
            return false;
        }
        form = nextForm;
        if (nextForm === "add-folder" && !draft.folderId)
            service.requestFolderIdSuggestion();
        return true;
    }

    function closeForm() {
        if (submitting)
            return false;
        confirmation = null;
        form = "";
        draft = ({});
        originalShareIds = [];
        error = "";
        focusRequested(returnFocus);
        returnFocus = null;
        return true;
    }

    function cancelConfirmation() {
        if (submitting)
            return false;
        confirmation = null;
        focusRequested(returnFocus);
        return true;
    }

    function requestConfirmation(action, target, trigger) {
        if (busy)
            return false;
        confirmation = {
            action: action,
            target: JSON.parse(JSON.stringify(target || {}))
        };
        returnFocus = trigger || returnFocus;
        error = "";
        return true;
    }

    function reject(message) {
        error = message;
        submitting = false;
        pendingAction = "";
        return false;
    }

    function submit() {
        if (busy || !service)
            return false;
        error = "";
        submitting = true;
        submittedDraft = JSON.parse(JSON.stringify(draft));
        var accepted = false;
        if (form === "add-folder") {
            pendingAction = "folder.add-existing";
            accepted = service.addFolder(Object.assign({}, draft, {
                deviceIds: draft.ids.slice()
            }));
        } else if (form === "add-device" || form === "accept-device") {
            pendingAction = "device.add";
            accepted = service.addDevice(draft.deviceId, draft.name);
        } else if (form === "share-folder") {
            if (!service.folder(draft.folderId))
                return reject("This folder no longer exists; your draft has been kept");
            pendingAction = "folder.set-sharing";
            accepted = service.setFolderSharing(draft.folderId, draft.ids.slice());
        } else if (form === "device-folders") {
            if (!service.device(draft.deviceId))
                return reject("This device no longer exists; your draft has been kept");
            pendingAction = "device.remove-folder-shares";
            accepted = service.removeDeviceFolderShares(draft.deviceId, Model.removedShares(originalShareIds, draft.ids), draft.name);
        }
        if (!accepted)
            return reject(service.actionError || "Action is unavailable");
        return true;
    }

    function requestServiceToggle(trigger) {
        if (!service || !service.canControlService || busy || form || confirmation)
            return false;
        return requestConfirmation(service.lifecycle.active ? "lifecycle.stop" : "lifecycle.start", {}, trigger);
    }

    function confirm() {
        if (busy || !confirmation || !service)
            return false;
        var request = confirmation;
        var target = request.target;
        var action = request.action;
        var accepted = false;
        if (action === "folder.forget" && !service.folder(target.id) || action === "device.remove" && !service.device(target.id))
            return reject("This target no longer exists; nothing was changed");
        submitting = true;
        pendingAction = action;
        if (action === "folder.forget")
            accepted = service.forgetFolder(target.id);
        else if (action === "device.remove")
            accepted = service.removeDevice(target.id, target.name);
        else if (action === "device.dismiss-pending")
            accepted = service.dismissPendingDevice(target.id, target.name);
        else if (action === "folder.dismiss-pending")
            accepted = service.dismissPendingFolder(target.folderId, target.deviceId);
        else if (action === "folder.add-existing")
            accepted = service.addFolder(Object.assign({}, target, {
                createDirectory: true
            }));
        else if (action === "lifecycle.start" || action === "lifecycle.stop")
            accepted = service.runAction(action, {}, action === "lifecycle.start" ? "Syncthing started" : "Syncthing stopped", "");
        if (!accepted)
            return reject(service.actionError || "Action is unavailable");
        return true;
    }

    function settled(action, ok, data, failure) {
        if (action === "folder.resume") {
            if (ok && linkingFolderId) {
                recentlyLinkedFolderId = linkingFolderId;
                linkedFeedback.restart();
            }
            linkingFolderId = "";
        }
        if (action === "folder.suggest-id") {
            if (ok && form === "add-folder" && !draft.folderId)
                setDraft("folderId", String(data && data.folderId || ""));
            return;
        }
        if (!pendingAction || action !== pendingAction)
            return;
        submitting = false;
        pendingAction = "";
        if (!ok) {
            error = String(failure && failure.message || "Action failed; your draft has been kept");
            if (action === "folder.add-existing" && failure && failure.code === "path_missing" && !confirmation) {
                requestConfirmation("folder.add-existing", Object.assign({}, submittedDraft, {
                    deviceIds: (submittedDraft.ids || []).slice()
                }), returnFocus);
            }
            return;
        }
        confirmation = null;
        closeForm();
    }

    onServiceChanged: reconcile()

    property Connections serviceConnections: Connections {
        target: root.service
        function onFoldersChanged() {
            root.reconcile();
        }
        function onDevicesChanged() {
            root.reconcile();
        }
        function onActionFinished(action, ok, data, error) {
            root.settled(action, ok, data, error);
        }
    }
}
