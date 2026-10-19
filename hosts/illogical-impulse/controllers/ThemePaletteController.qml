import QtQuick

QtObject {
    id: root
    required property var service
    required property var settings
    property var palette: ({})
    property string error: ""
    property string applied: ""
    property string requested: ""
    property string failed: ""
    readonly property bool selected: settings.values.webUi === "themed" && service.webUi.theme === "syncshell-illogical-impulse-themed"
    readonly property string paletteKey: JSON.stringify(palette)

    function retry() {
        if (!selected || !service.online || service.busy) return false;
        failed = "";
        applied = "";
        error = "";
        updatePalette();
        return requested !== "";
    }
    function updatePalette() {
        if (!selected || !service.online || service.busy || !palette.mode || (paletteKey === applied || paletteKey === failed))
            return;
        requested = paletteKey;
        if (!service.runAction("webui.refresh-profile", {
            profile: "themed",
            palette: palette
        }, "", ""))
            requested = "";
    }
    onPaletteKeyChanged: debounce.restart()
    onSelectedChanged: if (selected)
        debounce.restart()
    property Timer debounce: Timer {
        interval: 250
        onTriggered: root.updatePalette()
    }
    property Connections results: Connections {
        target: root.service
        function onOnlineChanged() {
            if (root.service.online && root.selected)
                debounce.restart();
        }
        function onBusyChanged() {
            if (!root.service.busy && root.selected)
                debounce.restart();
        }
        function onActionFinished(action, ok, data, failure) {
            if (action === "webui.refresh-profile" && root.requested) {
                if (ok) {
                    root.applied = root.requested;
                    root.error = "";
                } else {
                    root.failed = root.requested;
                    root.error = String(failure && failure.message || "Host palette refresh failed");
                }
                root.requested = "";
            }
        }
    }
}
