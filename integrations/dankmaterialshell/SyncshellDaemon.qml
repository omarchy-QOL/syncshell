import QtQuick
import qs.Modules.Plugins
import "shared"
import "shared/Paths.js" as Paths

PluginComponent {
    id: root

    property var popoutService: null
    property AdapterService service: AdapterService {
        pluginRoot: Paths.localPath(Qt.resolvedUrl("."))
        refreshIntervalSeconds: Math.max(60, Number(root.pluginData.refreshIntervalSec || 60))
    }

    function publishService() {
        if (pluginService && pluginId)
            pluginService.setGlobalVar(pluginId, "service", service);
    }

    Component.onCompleted: publishService()
    Component.onDestruction: {
        if (pluginService && pluginId && pluginService.getGlobalVar(pluginId, "service", null) === service)
            pluginService.setGlobalVar(pluginId, "service", null);
    }
    onPluginServiceChanged: publishService()
    onPluginIdChanged: publishService()
}
