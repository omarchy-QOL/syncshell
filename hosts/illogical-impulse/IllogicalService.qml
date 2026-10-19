import QtQuick
import "../../shared" as Shared
import "../../shared/Paths.js" as Paths
import "models/PanelModel.js" as Model

Shared.AdapterService {
    id: root
    property bool active: false
    property bool monochromeIcon: false
    lifecyclePolicy: ({
            kind: "systemd-user",
            unit: "syncthing.service",
            authorized: true
        })
    desiredServiceState: "disabled"
    desktopAuthorized: true
    profilePolicy: ({
            authorized: true,
            owner: "illogical-impulse",
            bundle: bundleRoot + "/webui"
        })
    core.desiredRunning: active

    property bool recovering: false
    property Timer noticeTimer: Timer {
        interval: 5000
        onTriggered: root.actionNotice = ""
    }
    onActionNoticeChanged: if (actionNotice) noticeTimer.restart()

    function refreshStatus() {
        if (busy || refreshing) return false;
        actionError = "";
        actionNotice = "";
        if (!core.protocolReady) {
            recovering = core.restart();
            if (recovering) actionNotice = "Restarting the Syncshell core";
            return recovering;
        }
        if (online && Model.diagnostics(folders, connection.fresh).length)
            return runAction("folder.recheck-errors", {}, "Status refreshed and folder errors rechecked", "");
        _refreshRequest = core.refresh(function (ok, data, failure) {
            root._refreshRequest = "";
            if (ok) root.actionNotice = "Syncthing status refreshed";
            else root.actionError = root.errorText(failure, "Status refresh failed");
        });
        return _refreshRequest !== "";
    }
    property Connections recovery: Connections {
        target: root.core
        function onProtocolReadyChanged() {
            if (root.recovering && root.core.protocolReady) {
                root.recovering = false;
                Qt.callLater(root.refreshStatus);
            }
        }
    }

    function folderArguments(value) {
        return {
            folderId: String(value.folderId || "").trim(),
            path: Paths.resolveFolderPath(value.path, homePath),
            label: String(value.label || "").trim(),
            deviceIds: (value.deviceIds || []).slice(),
            pendingDeviceId: String(value.pendingDeviceId || ""),
            createDirectory: value.createDirectory === true
        };
    }

    onActiveChanged: {
        if (active)
            core.start();
        else
            core.terminate();
    }
}
