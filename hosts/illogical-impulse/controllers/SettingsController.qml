import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    required property var service
    property bool ready: false
    property string error: ""
    property var values: ({
            version: 1,
            monochrome: false,
            probeIntervalSeconds: 15,
            refreshIntervalSeconds: 60,
            webUi: "default"
        })
    property var draft: ({})
    property bool opened: false
    property bool saving: false
    property bool hasDraft: false
    property var submitted: null
    property bool writePending: false
    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/syncshell/illogical-impulse.json"

    function begin() {
        if (!hasDraft) {
            draft = Object.assign({}, values);
            hasDraft = true;
        }
        opened = true;
    }
    function edit(key, value) {
        if (!saving)
            draft = Object.assign({}, draft, {
                [key]: value
            });
    }
    function cancel() {
        if (!saving) {
            opened = false;
            draft = ({});
            hasDraft = false;
            error = "";
        }
    }
    function save(palette, reapply) {
        if (saving || service.busy || service.refreshing || !hasDraft)
            return false;
        var probe = Number(draft.probeIntervalSeconds), refresh = Number(draft.refreshIntervalSeconds);
        if (!Number.isInteger(probe) || probe < 1 || probe > 3600 || !Number.isInteger(refresh) || refresh < 60 || refresh > 3600) {
            error = "Probe: 1–3600 seconds; refresh: 60–3600 seconds";
            return false;
        }
        if (["default", "modern", "themed"].indexOf(draft.webUi) < 0) {
            error = "Choose a supported Web UI profile";
            return false;
        }
        error = "";
        submitted = Object.assign({}, draft, {
            probeIntervalSeconds: probe,
            refreshIntervalSeconds: refresh
        });
        saving = true;
        if (reapply === true || submitted.webUi !== values.webUi) {
            var accepted = submitted.webUi === "default" ? service.setWebUiTheme("default") : service.applyWebProfile(submitted.webUi, submitted.webUi === "themed" ? palette : ({}));
            if (!accepted) {
                error = "Profile update is unavailable; check the connection";
                saving = false;
                submitted = null;
                return false;
            }
        } else
            directory.running = true;
        return true;
    }
    function finishSave() {
        values = submitted;
        ready = true;
        submitted = null;
        saving = false;
        opened = false;
        hasDraft = false;
    }
    function writeSettings() {
        writePending = false;
        var text = JSON.stringify(submitted, null, 2) + "\n";
        if (storage.loaded && storage.text() === text) finishSave();
        else storage.setText(text);
    }
    property Process directory: Process {
        command: ["mkdir", "-p", root.path.slice(0, root.path.lastIndexOf("/"))]
        onExited: code => {
            if (code === 0) {
                // Reload discards a failed write's cached text before retrying.
                root.writePending = true;
                storage.reload();
            } else {
                root.error = "Could not create the settings directory";
                root.saving = false;
            }
        }
    }
    property Connections results: Connections {
        target: root.service
        function onActionFinished(action, ok, data, failure) {
            if (action === "webui.remove-profile" && ok) {
                root.saving = true;
                root.values = Object.assign({}, root.values, {
                    webUi: "default"
                });
                root.draft = Object.assign({}, root.draft, {
                    webUi: "default"
                });
                root.submitted = root.values;
                directory.running = true;
            } else if (root.saving && (action === "webui.apply-profile" || action === "webui.set-theme")) {
                if (ok)
                    directory.running = true;
                else {
                    root.error = String(failure && failure.message || "Profile update failed");
                    root.saving = false;
                }
            }
        }
    }
    property FileView storage: FileView {
        path: root.path
        blockLoading: false
        printErrors: false
        onLoaded: {
            if (root.writePending) { Qt.callLater(root.writeSettings); return; }
            try {
                var next = JSON.parse(text());
                if (next.version !== 1)
                    throw new Error("Unsupported settings version");
                if (typeof next.monochrome !== "boolean" || !Number.isInteger(next.probeIntervalSeconds) || next.probeIntervalSeconds < 1 || next.probeIntervalSeconds > 3600 || !Number.isInteger(next.refreshIntervalSeconds) || next.refreshIntervalSeconds < 60 || next.refreshIntervalSeconds > 3600 || ["default", "modern", "themed"].indexOf(next.webUi) < 0)
                    throw new Error("Invalid Syncshell settings; correct " + root.path);
                root.values = Object.assign({}, root.values, next);
                root.ready = true;
            } catch (error) {
                root.error = String(error);
            }
        }
        onLoadFailed: error => {
            if (root.writePending) {
                if (error === FileViewError.FileNotFound) Qt.callLater(root.writeSettings);
                else {
                    root.writePending = false;
                    root.saving = false;
                    root.error = "Could not read settings before saving";
                }
                return;
            }
            if (error === FileViewError.FileNotFound)
                root.ready = true;
            else
                root.error = "Could not read Syncshell settings";
        }
        onSaved: root.finishSave()
        onSaveFailed: {
            root.error = "Could not save Syncshell settings";
            root.saving = false;
        }
    }
}
