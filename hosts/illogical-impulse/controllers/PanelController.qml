import QtQuick
import "../models/PanelModel.js" as Model
import "../../../shared" as Shared

QtObject {
    id: root
    required property var service
    property string tab: "folders"
    property string folderId: ""
    property string deviceId: ""
    property var groups: ["ready", "active", "errors", "paused", "unknown"]
    property string sort: "name"
    property bool more: false
    property string diagnosticFolderId: ""
    property bool viewOptionsOpen: false
    property string pendingDeviceId: ""
    property string pendingOfferId: ""
    property var queries: ({})
    property var selectorStack: []
    property string triggerKey: "panel"
    property bool presentationActive: true
    property bool preparing: false
    property string preparationError: ""
    property string view: ""
    property bool formVisible: false
    property var draft: ({})
    property var originalShareIds: []
    property var confirmation: null
    property bool confirmationVisible: false
    property var submitted: null
    property string copiedId: ""
    property Timer copyTimer: Timer {
        interval: 1800
        onTriggered: root.copiedId = ""
    }
    function recordCopy(value) { copiedId = value; copyTimer.restart(); }
    property string error: ""
    property int draftGeneration: 0
    property int suggestionGeneration: -1
    property bool idEdited: false
    property string selector: ""
    property string lastSelector: ""
    property string query: ""
    property real formOffset: 0
    property var focusTrigger: null

    readonly property var folder: Model.byId(service.folders, folderId)
    readonly property var device: Model.byId(service.devices, deviceId)
    readonly property var folderRows: Model.folderOptions(service.folders, service.online && service.connection.fresh, groups, sort, "")
    readonly property bool pending: submitted !== null
    readonly property bool blocked: pending || service.busy || service.refreshing === true
    readonly property var tracked: Model.totals(service.folders)
    readonly property var diagnosticRows: Model.diagnostics(service.folders, service.online && service.connection.fresh)
    readonly property var offerRows: Model.offerOptions(service.pendingFolderOffers ? service.pendingFolderOffers() : [], id => service.deviceName(id))
    readonly property var selectedOffer: Model.byId(offerRows, pendingOfferId)
    readonly property var pendingDevice: Model.byId(service.pendingDevices || [], pendingDeviceId)
    readonly property var removedShareIds: view === "device-folders" ? service.folderIdsForDevice(draft.deviceId).filter(id => (draft.folderIds || []).indexOf(id) < 0) : []
    readonly property bool noSharingChange: view === "device-folders" && removedShareIds.length === 0
    readonly property string validation: view === "add-folder" ? Model.folderValidation(draft, service.folders)
        : view === "add-device" || view === "accept-device"
            ? Model.deviceValidation(draft.deviceId, service.localDeviceId, service.devices) : ""
    readonly property bool targetMissing: view === "share-folder" && !service.folder(draft.folderId) || view === "device-folders" && !service.device(draft.deviceId)

    signal focusRequested(string key)
    signal closeRequested
    signal revealRequested(string key)
    signal browseRequested

    property Shared.DeviceWorkflow deviceWorkflow: Shared.DeviceWorkflow {
        service: root.service
    }

    function rememberTrigger(item) {
        focusTrigger = item;
        triggerKey = item.objectName || "panel";
        formOffset = item.mapToItem(null, 0, 0).y;
    }

    function restoreTrigger() {
        if (focusTrigger)
            focusTrigger.focusControl();
        else
            focusRequested(triggerKey);
    }

    function begin(viewName, values) {
        if (pending || confirmation) {
            reopen();
            error = pending ? "Wait for the current operation to finish" : "Finish or cancel the current confirmation";
            return false;
        }
        if (view) {
            let same = view === viewName && (viewName === "add-device"
                || viewName === "add-folder" && draft.pendingDeviceId === (values.pendingDeviceId || "")
                    && (!values.pendingDeviceId || draft.folderId === values.folderId)
                || viewName !== "add-folder" && viewName !== "add-device"
                    && draft.deviceId === values.deviceId && draft.folderId === values.folderId);
            formVisible = true;
            error = same ? "" : "Resume or cancel the existing draft before opening a different target";
            focusRequested("first-field");
            return false;
        }
        draftGeneration++;
        view = viewName;
        draft = Model.clone(values || {});
        formVisible = true;
        error = "";
        focusRequested("first-field");
        return true;
    }

    function addFolder(offer) {
        if (offer && offer.encrypted)
            return service.openWebUi();
        if (!begin("add-folder", Model.folderDraft(offer)))
            return false;
        idEdited = !!offer;
        if (!offer) generateFolderId();
        return true;
    }

    function addDevice(value, accepting) {
        deviceWorkflow.beginAddDevice(value);
        return begin(accepting ? "accept-device" : "add-device", {
            deviceId: deviceWorkflow.targetDeviceId,
            deviceName: deviceWorkflow.targetDeviceName,
            address: value ? String(value.address || "") : "",
            sourceId: value ? String(value.id || "") : "manual"
        });
    }

    function shareFolder(value) {
        deviceWorkflow.beginFolderSharing(value);
        return begin("share-folder", {
            folderId: value.id,
            deviceIds: deviceWorkflow.draftIds.slice()
        });
    }

    function deviceFolders(value) {
        if (view || pending || confirmation) return begin("device-folders", {deviceId: value.id});
        deviceWorkflow.beginDeviceFolders(value);
        originalShareIds = deviceWorkflow.draftIds.slice();
        return begin("device-folders", {
            deviceId: value.id,
            folderIds: deviceWorkflow.draftIds.slice()
        });
    }

    function reconcileShares() {
        if (view !== "device-folders" || pending)
            return;
        var current = service.folderIdsForDevice(draft.deviceId);
        var selected = current.filter(id => originalShareIds.indexOf(id) < 0 || draft.folderIds.indexOf(id) >= 0);
        originalShareIds = current.slice();
        draft = Object.assign({}, draft, {
            folderIds: selected
        });
    }

    function edit(key, value) {
        if (pending)
            return;
        var next = Model.clone(draft);
        next[key] = key === "deviceId" ? Model.normalizeDeviceId(value) : value;
        draft = next;
        if (key === "folderId")
            idEdited = true;
        error = "";
    }

    function discard() {
        if (pending)
            return false;
        view = "";
        draft = ({});
        formVisible = false;
        draftGeneration++;
        closeMenus();
        preparationError = "";
        deviceWorkflow.close();
        restoreTrigger();
        return true;
    }

    function reopen() {
        formVisible = view !== "";
        confirmationVisible = confirmation !== null;
        focusRequested(confirmation ? "cancel-confirm" : view ? "first-field" : "panel");
    }

    function handleEscape() {
        if (viewOptionsOpen) {
            viewOptionsOpen = false;
            focusRequested("folder-view-options");
        } else if (selector) {
            closeSelector();
        } else if (confirmationVisible) {
            confirmationVisible = false;
            restoreTrigger();
        } else if (formVisible) {
            formVisible = false;
            restoreTrigger();
        } else
            closeRequested();
    }

    function resetView() {
        groups = ["ready", "active", "errors", "paused", "unknown"];
        sort = "name";
    }

    function ask(action, args, title, detail) {
        if (pending || confirmation || service.busy)
            return false;
        confirmation = {
            action: action,
            args: Model.clone(args),
            title: title,
            detail: detail || "",
            presentation: Model.actionDescription(action, args, targetLabel(args)),
            generation: (action === "folder.add-existing" || action === "device.remove-folder-shares") ? draftGeneration : -1
        };
        confirmationVisible = true;
        focusRequested("cancel-confirm");
        return true;
    }

    function cancelConfirmation() {
        if (pending)
            return;
        confirmation = null;
        confirmationVisible = false;
        restoreTrigger();
    }

    function confirm(autoRepeat) {
        if (autoRepeat || !confirmation || pending)
            return false;
        var value = confirmation;
        if (!execute(value.action, value.args, value.generation))
            return false;
        confirmation = null;
        confirmationVisible = false;
        return true;
    }

    function execute(action, args, generation) {
        if (pending || service.busy)
            return false;
        var frozen = Model.clone(args);
        submitted = {
            action: action,
            args: frozen,
            generation: generation
        };
        if (!service.runAction(action, frozen, Model.actionDescription(action, frozen, targetLabel(frozen)).success, frozen.folderId || frozen.deviceId || "")) {
            submitted = null;
            return false;
        }
        error = "";
        return true;
    }

    function save() {
        if (blocked || validation || targetMissing || noSharingChange)
            return false;
        if (view === "add-folder")
            return execute("folder.add-existing", service.folderArguments(draft), draftGeneration);
        if (view === "add-device" || view === "accept-device")
            return execute("device.add", {deviceId: Model.normalizeDeviceId(draft.deviceId),
                deviceName: String(draft.deviceName || "").trim()}, draftGeneration);
        if (view === "share-folder")
            return execute("folder.set-sharing", draft, draftGeneration);
        if (view === "device-folders") {
            let removed = removedShareIds.slice();
            return ask("device.remove-folder-shares", {
                deviceId: draft.deviceId,
                folderIds: removed
            }, "Remove selected shares?", "Files remain on both devices.");
        }
        return false;
    }

    function settled(action, ok, data, failure) {
        if (action === "folder.suggest-id") {
            preparing = false;
            if (view === "add-folder" && suggestionGeneration === draftGeneration && !idEdited) {
                if (ok) draft = Object.assign({}, draft, {folderId: String(data.folderId || "")});
                else preparationError = String(failure && failure.message || "Could not prepare a new folder ID; retry or enter one manually");
            }
        }
        if (!submitted || submitted.action !== action)
            return;
        var completed = submitted;
        submitted = null;
        if (!ok) {
            error = String(failure && failure.message || "Operation failed");
            if (action === "folder.add-existing" && failure && failure.code === "path_missing" && !completed.args.createDirectory) {
                let args = Model.clone(completed.args);
                args.createDirectory = true;
                ask(action, args, "Create this directory?", args.path);
            }
            return;
        }
        if (action === "folder.add-existing")
            folderId = completed.args.folderId;
        if (action === "device.add")
            deviceId = completed.args.deviceId;
        if (completed.generation === draftGeneration && view)
            discard();
    }

    function targetLabel(args) {
        return args.folderId ? service.folderLabel(args.folderId)
            : args.deviceId ? (args.deviceName || service.deviceName(args.deviceId)) : "Syncthing";
    }

    function generateFolderId() {
        if (blocked || preparing || view !== "add-folder") return false;
        draft = Object.assign({}, draft, {pendingDeviceId: ""});
        idEdited = false;
        preparationError = "";
        suggestionGeneration = draftGeneration;
        preparing = service.requestFolderIdSuggestion();
        if (!preparing) preparationError = "ID preparation is unavailable; retry or enter an ID manually";
        return preparing;
    }

    function chooseFolderOffer(key) {
        if (blocked || view !== "add-folder") return false;
        var row = Model.byId(offerRows, key);
        if (!row) { error = "This invitation is no longer available"; return false; }
        if (row.offer.encrypted) { error = "Encrypted invitations must be accepted in the Web UI"; return false; }
        draftGeneration++;
        idEdited = true;
        draft = Object.assign(Model.folderDraft(row.offer), {path: draft.path || ""});
        error = "";
        return true;
    }

    function chooseDeviceSource(id) {
        if (blocked || view !== "add-device") return;
        var value = Model.byId(service.nearbyDevices || [], id);
        if (id !== "manual" && !value) { error = "This nearby device is no longer available"; return; }
        draft = {sourceId: id, deviceId: value ? Model.normalizeDeviceId(value.id) : "",
            deviceName: value ? String(value.name || "") : "", address: ""};
        error = "";
    }

    function reconcileSelections() {
        var folderRows = service.folders || [], deviceRows = (service.devices || []).filter(row => row.id !== service.localDeviceId);
        if (!Model.byId(folderRows, folderId)) folderId = folderRows.length ? folderRows[0].id : "";
        if (!Model.byId(deviceRows, deviceId)) deviceId = deviceRows.length ? deviceRows[0].id : "";
        if (!Model.byId(service.pendingDevices || [], pendingDeviceId))
            pendingDeviceId = (service.pendingDevices || []).length ? service.pendingDevices[0].id : "";
        if (!Model.byId(offerRows, pendingOfferId)) pendingOfferId = offerRows.length ? offerRows[0].id : "";
    }

    function openSelector(key) {
        if (selector === key) { closeSelector(); return; }
        queries = Object.assign({}, queries, {[selector]: query});
        selectorStack = selector ? selectorStack.concat([selector]) : [];
        selector = key;
        lastSelector = key;
        query = queries[key] || "";
    }

    function closeSelector() {
        var previous = selector;
        queries = Object.assign({}, queries, {[selector]: query});
        var stack = selectorStack.slice();
        selector = stack.pop() || "";
        selectorStack = stack;
        query = queries[selector] || "";
        lastSelector = previous;
        focusRequested(previous + "-trigger");
    }

    function closeMenus() {
        queries = Object.assign({}, queries, {[selector]: query});
        selector = "";
        selectorStack = [];
        viewOptionsOpen = false;
    }

    function showDiagnostics(id) {
        more = true;
        diagnosticFolderId = id || "";
        Qt.callLater(() => revealRequested(id ? "diagnostic-" + id : "diagnostics"));
    }

    onTabChanged: closeMenus()
    Component.onCompleted: reconcileSelections()

    property Connections results: Connections {
        target: root.service
        function onFoldersChanged() {
            root.reconcileShares();
            root.reconcileSelections();
        }
        function onDevicesChanged() { root.reconcileSelections(); }
        function onPendingDevicesChanged() { root.reconcileSelections(); }
        function onPendingFoldersChanged() { root.reconcileSelections(); }
        function onActionFinished(action, ok, data, error) {
            root.settled(action, ok, data, error);
        }
    }
}
