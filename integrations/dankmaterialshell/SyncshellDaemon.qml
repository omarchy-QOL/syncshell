import QtQuick
import qs.Modules.Plugins
import "shared"

PluginComponent {
  id: root

  property var popoutService: null
  property AdapterService service: AdapterService {
    pluginRoot: root.localPath(Qt.resolvedUrl("."))
    refreshIntervalSeconds: Math.max(60,
      Number(root.pluginData.refreshIntervalSec || 60))
  }

  function localPath(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = value.slice(7)
    return decodeURIComponent(value)
  }

  function publishService() {
    if (pluginService && pluginId)
      pluginService.setGlobalVar(pluginId, "service", service)
  }

  Component.onCompleted: publishService()
  Component.onDestruction: {
    if (pluginService && pluginId
        && pluginService.getGlobalVar(pluginId, "service", null) === service)
      pluginService.setGlobalVar(pluginId, "service", null)
  }
  onPluginServiceChanged: publishService()
  onPluginIdChanged: publishService()
}
