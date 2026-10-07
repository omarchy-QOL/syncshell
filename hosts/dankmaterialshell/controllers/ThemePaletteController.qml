import QtQuick
import qs.Common

QtObject {
    id: root
    property var service: null
    property var settings: null
    readonly property string selection: settings ? settings.values.webUiTheme : "default"
    readonly property var palette: ({
            mode: Theme.isLightMode ? "light" : "dark",
            background: rgb(Theme.surface),
            surface: rgb(Theme.surfaceContainer),
            surfaceVariant: rgb(Theme.surfaceVariant),
            foreground: rgb(Theme.surfaceText),
            muted: rgb(Theme.surfaceVariantText),
            accent: rgb(Theme.primary),
            success: rgb(Theme.success),
            warning: rgb(Theme.warning),
            danger: rgb(Theme.error),
            border: rgb(Theme.outline),
            info: rgb(Theme.info)
        })
    readonly property string key: selection + (selection === "dms" ? JSON.stringify(palette) : "")
    property string pendingKey: ""
    property string error: ""
    property bool dirty: false
    property bool initialized: false
    readonly property bool busy: pendingKey !== ""

    function rgb(color) {
        function channel(value) {
            return Math.round(value * 255).toString(16).padStart(2, "0");
        }
        return "#" + channel(color.r) + channel(color.g) + channel(color.b);
    }

    function schedule() {
        dirty = true;
        debounce.restart();
    }

    function apply() {
        if (!dirty || !service || !service.online || service.busy || service.refreshing || busy)
            return;
        dirty = false;
        pendingKey = key;
        error = "";
        var accepted = selection === "default" ? service.setWebUiTheme("default") : service.applyWebProfile(selection === "dms" ? "themed" : "modern", selection === "dms" ? palette : {});
        if (!accepted) {
            pendingKey = "";
            error = service.actionError || "Web UI profile could not be applied";
        }
    }

    function cleanup() {
        if (!service || !service.online || service.busy || service.refreshing || busy)
            return false;
        dirty = false;
        pendingKey = "remove";
        error = "";
        if (service.removeWebProfile())
            return true;
        pendingKey = "";
        error = service.actionError || "Profile cleanup could not start";
        return false;
    }

    Component.onCompleted: {
        initialized = true;
        if (selection !== "default")
            schedule();
    }
    onSelectionChanged: if (initialized)
        schedule()
    onServiceChanged: {
        if (busy) {
            pendingKey = "";
            error = "The native worker changed before the profile operation completed";
        }
        if (initialized && service && selection !== "default")
            schedule();
    }
    onPaletteChanged: {
        if (initialized && selection === "dms" && service && service.webUi.theme === "syncshell-dms-themed")
            schedule();
    }
    property Timer debounce: Timer {
        interval: 200
        onTriggered: root.apply()
    }
    property Connections serviceConnections: Connections {
        target: root.service
        function onOnlineChanged() {
            if (root.dirty)
                root.debounce.restart();
        }
        function onBusyChanged() {
            if (root.dirty)
                root.debounce.restart();
        }
        function onRefreshingChanged() {
            if (root.dirty)
                root.debounce.restart();
        }
        function onActionFinished(action, ok, data, failure) {
            if (!root.busy || ["webui.apply-profile", "webui.set-theme", "webui.remove-profile"].indexOf(action) < 0)
                return;
            var completed = root.pendingKey;
            root.pendingKey = "";
            if (!ok) {
                root.error = String(failure && failure.message || "Web UI profile operation failed");
                return;
            }
            if (completed === "remove") {
                root.settings.save("webUiTheme", "default");
            } else if (root.key !== completed) {
                root.schedule();
            }
        }
    }
}
