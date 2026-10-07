pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root
    property var settings: null
    readonly property string error: validate(settings)
    readonly property bool valid: settings !== null && error === ""

    function validate(s) {
        if (!s)
            return "Plugin settings are unavailable";
        if (s.schemaVersion !== 1)
            return "Incompatible Syncshell settings schema";
        if (!["sync", "cloud_sync", "folder"].includes(s.icon))
            return "Unsupported bar icon";
        if (!Number.isInteger(s.probeSeconds) || s.probeSeconds < 5 || s.probeSeconds > 300)
            return "Probe interval must be 5 to 300 seconds";
        if (!Number.isInteger(s.refreshSeconds) || s.refreshSeconds < 60 || s.refreshSeconds > 3600)
            return "Refresh interval must be 60 to 3600 seconds";
        if (!["default", "modern", "themed"].includes(s.webUiStyle))
            return "Unsupported Web UI selection";
        if (s.lifecycleAuthorized && (!s.lifecycleUnit.trim() || !s.lifecycleConfig.startsWith("/")))
            return "Service control requires an exact unit and absolute configuration path";
        return "";
    }
    function values() {
        var result = {};
        if (settings)
            settings.keys().forEach(key => result[key] = settings[key]);
        return result;
    }
    function save(draft) {
        var failure = validate(draft);
        if (failure)
            return failure;
        Object.keys(draft).forEach(key => settings[key] = draft[key]);
        return "";
    }
}
