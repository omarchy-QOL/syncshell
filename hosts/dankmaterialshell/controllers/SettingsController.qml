import QtQuick

QtObject {
    id: root

    property var pluginService: null
    property string pluginId: "syncshell"
    property var pluginData: ({})
    readonly property string owner: "omarchy-QOL/syncshell"
    readonly property var defaults: ({
            schema: 1,
            owner: root.owner,
            iconStyle: "themed",
            webUiTheme: "default",
            probeIntervalSeconds: 15,
            refreshIntervalSeconds: 60,
            lifecycleAuthorized: false,
            lifecycleUnit: "syncthing.service",
            lifecycleConfig: "",
            desiredServiceState: "enabled",
            configPath: "",
            endpoint: "",
            credentialFile: "",
            tlsCertificate: "",
            expectedDeviceId: ""
        })
    readonly property string validationError: validate(pluginData)
    readonly property bool valid: validationError === ""
    readonly property var values: valid ? Object.assign({}, defaults, pluginData.syncshell || {}) : defaults
    property string writeError: ""

    function validate(data) {
        if (!data || typeof data !== "object" || Array.isArray(data))
            return "Invalid Syncshell settings; no settings were changed";
        var keys = Object.keys(data);
        for (var index = 0; index < keys.length; index++) {
            if (["syncshell", "enabled", "variants", "displayPreferences"].indexOf(keys[index]) < 0)
                return "Unrecognized settings for plugin ID syncshell. Back up and remove the other installation first";
        }
        if (data.syncshell === undefined)
            return "";
        var config = data.syncshell;
        if (!config || config.schema !== 1 || config.owner !== owner)
            return "These settings belong to another Syncshell version or plugin; automatic migration is disabled";
        var configKeys = Object.keys(config);
        for (var keyIndex = 0; keyIndex < configKeys.length; keyIndex++) {
            var key = configKeys[keyIndex];
            if (!Object.prototype.hasOwnProperty.call(defaults, key) || typeof config[key] !== typeof defaults[key])
                return "Unsupported Syncshell setting: " + key;
        }
        var value = Object.assign({}, defaults, config);
        if (["themed", "branded"].indexOf(value.iconStyle) < 0 || ["default", "modern", "dms"].indexOf(value.webUiTheme) < 0)
            return "Unsupported icon or Web UI theme";
        if (!Number.isInteger(value.probeIntervalSeconds) || value.probeIntervalSeconds < 1 || value.probeIntervalSeconds > 3600 || !Number.isInteger(value.refreshIntervalSeconds) || value.refreshIntervalSeconds < 1 || value.refreshIntervalSeconds > 3600)
            return "Probe and refresh intervals must be whole seconds between 1 and 3600";
        if (["enabled", "disabled"].indexOf(value.desiredServiceState) < 0)
            return "Unsupported desired service state";
        if (value.lifecycleAuthorized && !/^[A-Za-z0-9_.@:-]+\.service$/.test(value.lifecycleUnit))
            return "Choose an exact systemd user service unit";
        return "";
    }

    function save(key, value) {
        if (!valid || !pluginService)
            return false;
        var next = Object.assign({}, values);
        next[key] = value;
        writeError = validate({
            syncshell: next
        });
        if (writeError)
            return false;
        pluginService.savePluginData(pluginId, "syncshell", next);
        return true;
    }
}
