import QtQuick
import Quickshell
import "."
import "Paths.js" as Paths

QtObject {
    id: root

    property int probeIntervalSeconds: 15
    property int refreshIntervalSeconds: 60
    property bool startCore: true
    property string bundleRoot: Paths.localFilePath(Qt.resolvedUrl(".."))
    property var lifecyclePolicy: ({})
    property string desiredServiceState: "disabled"
    property bool desktopAuthorized: false
    property var profilePolicy: ({})
    property string configPath: ""
    property string endpoint: ""
    property string credentialFile: ""
    property string tlsCertificate: ""
    property string expectedDeviceId: ""
    readonly property string homePath: Quickshell.env("HOME") || ""

    readonly property var state: core.snapshot || ({})
    readonly property var connection: state.connection || ({})
    readonly property var identity: state.identity || ({})
    readonly property var counts: state.counts || ({})
    readonly property var truncation: state.truncation || ({})
    readonly property var activity: state.activity || ({})
    readonly property var currentActivity: activity.current || ({})
    readonly property var webUi: state.webUi || ({})
    readonly property var lifecycle: state.lifecycle || ({})
    readonly property var installation: state.installation || ({})
    readonly property bool lifecycleAuthorized: lifecyclePolicy.authorized === true
        && lifecyclePolicy.kind === "systemd-user" && !!lifecyclePolicy.unit
    readonly property bool canControlService: lifecycleAuthorized
        && lifecycle.authorized === true && lifecycle.canControl === true
    readonly property bool canStartService: canControlService && lifecycle.canStart === true
    readonly property var folders: state.folders || []
    readonly property var devices: state.devices || []
    readonly property var pendingFolders: state.pendingFolders || ({})
    readonly property var pendingDevices: state.pendingDevices || []
    readonly property var nearbyDevices: state.nearbyDevices || []
    readonly property string localDeviceId: String(identity.deviceId || "")
    readonly property bool online: core.protocolReady && connection.online === true
    readonly property bool refreshing: _refreshRequest !== ""
    readonly property bool busy: _actionRequest !== ""
    readonly property bool folderMutationBusy: busy
    readonly property bool folderPreparationBusy: _actionName === "folder.suggest-id"
    readonly property int folderCount: Number(counts.folders || 0)
    readonly property int deviceCount: Number(counts.devices || 0)
    readonly property int connectedDeviceCount: Number(counts.connectedDevices || 0)
    readonly property int folderProblemCount: Number(counts.folderProblems || 0)
    readonly property int syncingFolderCount: Number(counts.syncingFolders || 0)
    readonly property string phase: core.starting ? "core-starting" : core.incompatible ? "core-incompatible" : core.unavailable && !core.running ? "core-unavailable" : String(connection.phase || "discovering")
    readonly property string lastError: actionError || core.lastError || String(connection.error && connection.error.message || "")
    readonly property string summaryText: summary()
    readonly property string baseUrl: String(webUi.url || "")
    readonly property string activityText: currentActivity.detail ? String(currentActivity.action || "Syncing") + " " + String(currentActivity.detail) : ""

    property string actionError: ""
    property string actionNotice: ""
    property string folderIdSuggestion: ""
    property string _refreshRequest: ""
    property string _actionRequest: ""
    property string _actionName: ""
    property string _actionTargetId: ""

    signal actionFinished(string action, bool ok, var data, var error)

    function summary() {
        if (phase === "core-starting")
            return "Starting Syncshell";
        if (phase === "discovering")
            return "Finding Syncthing";
        if (phase === "loading")
            return "Reading status";
        if (!online)
            return connection.authorized === false && connection.healthy === true ? "Syncthing authorization failed" : "Syncthing unavailable";
        if (folderProblemCount > 0)
            return folderProblemCount + " folder problem" + (folderProblemCount === 1 ? "" : "s");
        if (syncingFolderCount > 0)
            return syncingFolderCount + " folder" + (syncingFolderCount === 1 ? "" : "s") + " syncing";
        return folderCount === 0 ? "No folders configured" : "Up to date";
    }

    function errorText(error, fallback) {
        return String(error && error.message || fallback || "Action failed");
    }

    function device(deviceId) {
        var wanted = String(deviceId || "");
        for (let index = 0; index < devices.length; index++) {
            if (String(devices[index].id || "") === wanted)
                return devices[index];
        }
        return null;
    }

    function deviceName(deviceId) {
        var value = device(deviceId);
        return value && value.name ? String(value.name) : String(deviceId || "").split("-")[0];
    }

    function remoteDevices() {
        var result = [];
        for (let index = 0; index < devices.length; index++) {
            let value = devices[index] || ({});
            if (String(value.id || "") !== "" && String(value.id || "") !== localDeviceId)
                result.push(value);
        }
        return result;
    }

    function shareableDevices() {
        var result = [];
        var remote = remoteDevices();
        for (let index = 0; index < remote.length; index++) {
            if (remote[index].untrusted !== true)
                result.push(remote[index]);
        }
        return result;
    }

    function remoteDeviceIdsForFolder(folderId) {
        var value = folder(folderId);
        var members = value && value.devices ? value.devices : [];
        var result = [];
        for (let index = 0; index < members.length; index++) {
            let id = String((members[index] || {}).id || "");
            if (id !== "" && id !== localDeviceId)
                result.push(id);
        }
        return result;
    }

    function folderIdsForDevice(deviceId) {
        var wanted = String(deviceId || "");
        var result = [];
        for (let folderIndex = 0; folderIndex < folders.length; folderIndex++) {
            let members = folders[folderIndex].devices || [];
            for (let memberIndex = 0; memberIndex < members.length; memberIndex++) {
                if (String((members[memberIndex] || {}).id || "") === wanted) {
                    result.push(String(folders[folderIndex].id || ""));
                    break;
                }
            }
        }
        return result;
    }

    function pendingFolderOffers() {
        var result = [];
        var folderIds = Object.keys(pendingFolders).sort();
        for (let folderIndex = 0; folderIndex < folderIds.length; folderIndex++) {
            let folderId = folderIds[folderIndex];
            let offeredBy = (pendingFolders[folderId] || {}).offeredBy || ({});
            let deviceIds = Object.keys(offeredBy).sort();
            for (let deviceIndex = 0; deviceIndex < deviceIds.length; deviceIndex++) {
                let deviceId = deviceIds[deviceIndex];
                let offer = offeredBy[deviceId] || ({});
                result.push({
                    folderId: folderId,
                    deviceId: deviceId,
                    label: String(offer.label || folderId),
                    encrypted: offer.receiveEncrypted === true || offer.remoteEncrypted === true
                });
            }
        }
        return result;
    }

    function folder(folderId) {
        var wanted = String(folderId || "");
        for (let index = 0; index < folders.length; index++) {
            if (String(folders[index].id || "") === wanted)
                return folders[index];
        }
        return null;
    }

    function folderLabel(folderId) {
        var value = folder(folderId);
        return value ? String(value.label || value.id) : String(folderId || "");
    }

    function refresh() {
        if (refreshing || busy)
            return false;
        actionError = "";
        if (!core.protocolReady)
            return core.restart();
        _refreshRequest = core.refresh(function (ok, data, error) {
            root._refreshRequest = "";
            if (!ok)
                root.actionError = root.errorText(error, "Refresh failed");
        });
        return _refreshRequest !== "";
    }

    function runAction(name, args, notice, targetId) {
        var lifecycleAction = name.indexOf("lifecycle.") === 0;
        var available = core.protocolReady && (online || lifecycleAction && canStartService);
        if (!available || busy || refreshing) {
            actionError = available ? "Another operation is already running" : "Syncthing must be online";
            return false;
        }
        if (lifecycleAction && !canControlService) {
            actionError = "This Syncthing instance is externally managed";
            return false;
        }
        actionError = "";
        actionNotice = "";
        _actionName = name;
        _actionTargetId = String(targetId || "");
        rescanTracker.reset();
        _actionRequest = core.action(name, args || ({}), function (ok, data, error) {
            if (!ok) {
                root.finishAction(false, data, error);
                return;
            }
            if (root._actionName === "folder.rescan" || root._actionName === "folder.rescan-all") {
                if (!rescanTracker.acceptResult(data, root.scanningFolderIds())) {
                    root.finishAction(false, null, {
                        code: "invalid_result",
                        message: "Native core returned an invalid rescan result"
                    });
                }
                return;
            }
            if (root._actionName === "folder.suggest-id")
                root.folderIdSuggestion = String(data && data.folderId || "");
            root.actionNotice = String(notice || "");
            root.finishAction(true, data, null);
        });
        if (_actionRequest !== "")
            return true;
        actionError = "Native core is not ready";
        clearAction();
        return false;
    }

    function finishAction(ok, data, error) {
        var completed = _actionName;
        if (!ok)
            actionError = errorText(error, "Operation failed");
        clearAction();
        actionFinished(completed, ok, data || null, error || null);
    }

    function clearAction() {
        _actionRequest = "";
        _actionName = "";
        _actionTargetId = "";
        rescanTracker.reset();
    }

    function scanning(folderId) {
        var value = folder(folderId);
        return value && String(value.status && value.status.state || "").indexOf("scan") === 0;
    }

    function scanningFolderIds() {
        var result = [];
        for (let index = 0; index < folders.length; index++) {
            if (scanning(folders[index].id))
                result.push(String(folders[index].id));
        }
        result.sort();
        return result;
    }

    function completeRescan() {
        if (!busy || (_actionName !== "folder.rescan" && _actionName !== "folder.rescan-all"))
            return;
        actionNotice = _actionName === "folder.rescan-all" ? "Rescan complete for all folders" : "Rescan complete for " + folderLabel(_actionTargetId);
        finishAction(true, null, null);
    }

    function setFolderPaused(folderId, paused) {
        return runAction(paused ? "folder.pause" : "folder.resume", {
            folderId: folderId
        }, paused ? "Paused " + folderLabel(folderId) : "Resumed " + folderLabel(folderId), folderId);
    }

    function rescanFolder(folderId) {
        return runAction("folder.rescan", {
            folderId: folderId
        }, "", folderId);
    }

    function rescanAllFolders() {
        return runAction("folder.rescan-all", {}, "", "");
    }

    function forgetFolder(folderId) {
        return runAction("folder.forget", {
            folderId: folderId
        }, "Forgot " + folderLabel(folderId) + "; directory contents were kept", folderId);
    }

    function requestFolderIdSuggestion() {
        folderIdSuggestion = "";
        return runAction("folder.suggest-id", {}, "", "");
    }

    function addFolder(values) {
        var input = values || ({});
        return runAction("folder.add-existing", {
            folderId: String(input.folderId || input.id || ""),
            path: Paths.resolveFolderPath(input.path, homePath),
            createDirectory: input.createDirectory === true,
            label: String(input.label || ""),
            deviceIds: (input.deviceIds || input.selectedDeviceIds || []).slice(),
            pendingDeviceId: String(input.pendingDeviceId || "")
        }, "Added existing directory", String(input.folderId || input.id || ""));
    }

    function setFolderSharing(folderId, deviceIds) {
        return runAction("folder.set-sharing", {
            folderId: String(folderId || ""),
            deviceIds: deviceIds || []
        }, "Folder sharing updated", String(folderId || ""));
    }

    function addDevice(deviceId, name) {
        var label = String(name || "").trim() || "Device " + String(deviceId || "").slice(0, 7);
        return runAction("device.add", {
            deviceId: String(deviceId || ""),
            deviceName: String(name || "")
        }, label + " added; add this device there to complete the connection", String(deviceId || ""));
    }

    function dismissPendingDevice(deviceId, name) {
        var label = String(name || "").trim() || String(deviceId || "").slice(0, 7);
        return runAction("device.dismiss-pending", {
            deviceId: String(deviceId || "")
        }, "Dismissed pending request from " + label, String(deviceId || ""));
    }

    function setDevicePaused(deviceId, paused, name) {
        var label = String(name || "").trim() || "Device " + String(deviceId || "").slice(0, 7);
        return runAction(paused ? "device.pause" : "device.resume", {
            deviceId: String(deviceId || "")
        }, paused ? "Paused synchronization with " + label : "Resumed synchronization with " + label, String(deviceId || ""));
    }

    function removeDevice(deviceId, name) {
        var label = String(name || "").trim() || "Device " + String(deviceId || "").slice(0, 7);
        return runAction("device.remove", {
            deviceId: String(deviceId || "")
        }, label + " removed from this device", String(deviceId || ""));
    }

    function removeDeviceFolderShares(deviceId, folderIds, name) {
        var label = String(name || "").trim() || "Device " + String(deviceId || "").slice(0, 7);
        return runAction("device.remove-folder-shares", {
            deviceId: String(deviceId || ""),
            folderIds: folderIds || []
        }, "Selected folder shares removed from " + label, String(deviceId || ""));
    }

    function openWebUi() {
        if (!online || !baseUrl)
            return false;
        if (desktopAuthorized)
            return runAction("webui.open", {}, "", "");
        return Qt.openUrlExternally(baseUrl);
    }

    function dismissPendingFolder(folderId, deviceId) {
        return runAction("folder.dismiss-pending", {
            folderId: String(folderId || ""),
            pendingDeviceId: String(deviceId || "")
        }, "Folder invitation dismissed", String(folderId || ""));
    }

    function recheckErrors() {
        return runAction("folder.recheck-errors", {}, "Folder errors checked", "");
    }

    function setWebUiTheme(theme) {
        return runAction("webui.set-theme", { theme: String(theme || "") }, "Web UI theme updated", "");
    }

    function applyWebProfile(style, palette) {
        return runAction("webui.apply-profile", {
            profile: style, palette: palette || ({})
        }, "Web UI profile updated", "");
    }

    function removeWebProfile() {
        return runAction("webui.remove-profile", {}, "Default Web UI restored; this adapter's profiles removed", "");
    }

    function setServiceEnabled(enabled) {
        return runAction(enabled ? "lifecycle.enable" : "lifecycle.disable", {},
            enabled ? "Syncthing enabled" : "Syncthing disabled", "");
    }

    function startupArguments() {
        var args = ["--probe-interval-seconds", String(probeIntervalSeconds),
            "--desired-service-state", desiredServiceState];
        if (lifecycleAuthorized) {
            args.push("--lifecycle-kind", lifecyclePolicy.kind,
                "--lifecycle-authorized", "--lifecycle-unit", lifecyclePolicy.unit);
            if (lifecyclePolicy.configPath)
                args.push("--lifecycle-config", lifecyclePolicy.configPath);
        }
        if (desktopAuthorized)
            args.push("--desktop-authorized");
        if (profilePolicy.authorized === true)
            args.push("--web-profile-authorized", "--web-profile-owner", profilePolicy.owner,
                "--web-profile-bundle", profilePolicy.bundle);
        var targets = [
            ["--config", configPath], ["--endpoint", endpoint],
            ["--credential-file", credentialFile], ["--tls-certificate", tlsCertificate],
            ["--expected-device-id", expectedDeviceId]
        ];
        for (var index = 0; index < targets.length; index++) {
            if (targets[index][1])
                args.push(targets[index][0], targets[index][1]);
        }
        return args;
    }

    function configureCore() {
        if (!core || !core.protocolReady)
            return;
        core.configure({
            probeIntervalSeconds: probeIntervalSeconds,
            refreshIntervalSeconds: refreshIntervalSeconds,
            desiredServiceState: desiredServiceState
        });
    }

    onProbeIntervalSecondsChanged: configureCore()
    onRefreshIntervalSecondsChanged: configureCore()
    onDesiredServiceStateChanged: configureCore()
    onFoldersChanged: rescanTracker.reconcile(scanningFolderIds())
    onOnlineChanged: {
        if (!online && busy && (_actionName === "folder.rescan" || _actionName === "folder.rescan-all") && rescanTracker.runningFolderIds.length > 0) {
            finishAction(false, null, {
                code: "offline",
                message: "Could not confirm rescan completion because Syncthing became unavailable"
            });
        }
    }

    property RescanTracker rescanTracker: RescanTracker {
        onCompleted: root.completeRescan()
    }

    property CoreProcess core: CoreProcess {
        desiredRunning: root.startCore
        corePath: root.bundleRoot.replace(/\/$/, "") + "/bin/syncshell-core"
        startupArguments: root.startupArguments()
        onProtocolReadyChanged: if (protocolReady)
            root.configureCore()
        onRunningChanged: if (!running) {
            if (root._refreshRequest !== "") {
                root._refreshRequest = "";
                root.actionError = "Refresh stopped because the native core exited";
            }
            if (root._actionRequest !== "") {
                root.actionError = "Operation stopped because the native core exited";
                root.finishAction(false, null, {
                    code: "core_unavailable",
                    message: root.actionError
                });
            }
        }
    }
}
