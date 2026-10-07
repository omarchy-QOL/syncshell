import QtQuick
import qs.Modules.Plugins
import "../../shared" as Shared
import "../../shared/Paths.js" as Paths
import "controllers"

PluginComponent {
    id: root

    readonly property string bundleRoot: Paths.localFilePath(Qt.resolvedUrl("../.."))
    readonly property var service: serviceLoader.item
    readonly property var settings: settingsController
    readonly property var theme: themeController
    property string collisionError: ""
    property bool ownsService: false
    readonly property string error: collisionError || settings.validationError
    readonly property string connectionKey: JSON.stringify([
        settings.values.configPath, settings.values.endpoint, settings.values.credentialFile,
        settings.values.tlsCertificate, settings.values.expectedDeviceId,
        settings.values.lifecycleAuthorized, settings.values.lifecycleUnit,
        settings.values.lifecycleConfig
    ])

    function publish() {
        if (!pluginService || !pluginId)
            return;
        var existing = pluginService.getGlobalVar(pluginId, "host", null);
        var existingService = pluginService.getGlobalVar(pluginId, "service", null);
        if (existing && existing !== root || !existing && existingService && existingService !== service) {
            collisionError = "Another Syncshell service already owns this plugin ID";
            return;
        }
        ownsService = true;
        pluginService.setGlobalVar(pluginId, "host", root);
        pluginService.setGlobalVar(pluginId, "service", service);
    }

    Component.onCompleted: publish()
    onPluginServiceChanged: publish()
    onPluginIdChanged: publish()
    onServiceChanged: publish()
    Component.onDestruction: {
        if (pluginService && pluginService.getGlobalVar(pluginId, "host", null) === root) {
            pluginService.setGlobalVar(pluginId, "service", null);
            pluginService.setGlobalVar(pluginId, "host", null);
        }
    }

    SettingsController {
        id: settingsController
        pluginService: root.pluginService
        pluginId: root.pluginId
        pluginData: root.pluginData
    }

    ThemePaletteController {
        id: themeController
        service: root.service
        settings: settingsController
    }

    Loader {
        id: serviceLoader
        active: root.ownsService && settingsController.valid && !root.collisionError
        sourceComponent: Shared.AdapterService {
            bundleRoot: root.bundleRoot
            probeIntervalSeconds: settingsController.values.probeIntervalSeconds
            refreshIntervalSeconds: settingsController.values.refreshIntervalSeconds
            desiredServiceState: settingsController.values.desiredServiceState
            lifecyclePolicy: ({
                kind: "systemd-user", authorized: settingsController.values.lifecycleAuthorized,
                unit: settingsController.values.lifecycleUnit,
                configPath: settingsController.values.lifecycleConfig
            })
            desktopAuthorized: true
            profilePolicy: ({ authorized: true, owner: "dms", bundle: root.bundleRoot + "/webui" })
            configPath: settingsController.values.configPath
            endpoint: settingsController.values.endpoint
            credentialFile: settingsController.values.credentialFile
            tlsCertificate: settingsController.values.tlsCertificate
            expectedDeviceId: settingsController.values.expectedDeviceId

            onActionFinished: function (action, ok, data, failure) {
                if (ok && (action === "lifecycle.enable" || action === "lifecycle.disable"))
                    settingsController.save("desiredServiceState",
                        action === "lifecycle.enable" ? "enabled" : "disabled");
            }
        }
    }

    onConnectionKeyChanged: if (service) restartTimer.restart()

    Timer {
        id: restartTimer
        interval: 100
        onTriggered: if (root.service)
            root.service.core.restart()
    }
}
