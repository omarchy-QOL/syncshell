import QtQuick
import Quickshell
import "../hosts/omarchy"

ShellRoot {
    id: root
    property int step: 0

    OmarchyService {
        id: service
    }

    function check(value, message) {
        if (!value) {
            console.error(message);
            service.core.terminate();
            Qt.exit(1);
            throw new Error(message);
        }
    }

    function loseRescan() {
        var online = {
            connection: { online: true },
            folders: [{ id: "folder", status: { state: "scanning" } }]
        };
        service.core.snapshot = online;
        service.folderMutationBusy = true;
        service.folderMutationAction = "rescan";
        service.folderMutationId = "folder";
        check(service.rescanTracker.acceptResult({
            state: "running",
            targetFolderIds: ["folder"],
            runningFolderIds: ["folder"]
        }, ["folder"]), "accepted rescan is tracked");
        service.core.snapshot = Object.assign({}, online, { connection: { online: false } });
        check(!service.folderMutationBusy && service.rescanTracker.runningFolderIds.length === 0
              && service.folderMutationError !== "" && service.folderMutationNotice === "",
              "API loss clears an accepted rescan without reporting success");
        service.core.snapshot = online;
        service.folderMutationBusy = true;
        service.folderMutationAction = "rescan";
        service.folderMutationId = "folder";
        step = 5;
        service.core.coreProcess.signal(9);
    }

    Timer {
        interval: 25
        repeat: true
        running: true
        onTriggered: {
            if (root.step === 5) {
                if (service.folderMutationBusy)
                    return;
                root.check(!service.online && !service.canControlService, "core loss disables actions");
                root.check(service.folderMutationAction === "" && service.folderMutationId === "",
                           "core loss clears optimistic rescan state");
                root.check(service.folderMutationError === "Folder operation stopped because native core became unavailable",
                           "core loss reports the terminal rescan error");
                service.core.terminate();
                console.log("refresh and rescan recovery tests passed");
                Qt.quit();
                return;
            }
            if (!service.canRefresh)
                return;
            if (root.step === 0) {
                if (!service.online || !service.settingsReady)
                    return;
                root.step = 1;
                service.refresh();
            } else if (root.step === 1) {
                if (service.online)
                    return;
                root.check(service.lastError === "API unavailable", "failed refresh is visible through connection state");
                root.check(!service.statusFresh, "failed refresh is not fresh");
                root.step = 2;
                service.refresh();
            } else if (root.step === 2) {
                if (!service.online)
                    return;
                root.check(service.lastError === "" && service.controlError === "", "successful refresh must clear the prior refresh error");
                root.check(service.statusFresh, "recovered state is fresh");
                service.controlError = "service start failed";
                root.step = 3;
                service.refresh();
            } else if (root.step === 3) {
                if (service.folderProblemCount !== 1)
                    return;
                root.check(service.controlError === "service start failed", "refresh must not erase an unrelated lifecycle error");
                root.check(service.folderStatuses.folder.errors === 1, "current folder errors did not reach QML");
                root.step = 4;
                root.check(service.refresh(true), "error recheck was not started");
            } else {
                if (service.folderProblemCount !== 0)
                    return;
                root.check(service.folderStatuses.folder.errors === 0, "successful recheck must replace old folder errors");
                root.loseRescan();
            }
        }
    }

    Timer {
        interval: 8000
        running: true
        onTriggered: {
            console.error("refresh recovery test timed out");
            service.core.terminate();
            Qt.exit(1);
        }
    }
}
