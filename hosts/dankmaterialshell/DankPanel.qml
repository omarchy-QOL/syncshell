import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "controllers"
import "ui"

PluginComponent {
    id: root
    layerNamespacePlugin: "syncshell"
    popoutWidth: 440 + Theme.spacingS * 2
    property var service: null
    property var host: null
    readonly property string stateIcon: !service || !service.online ? "cloud_off" : service.folderProblemCount ? "sync_problem" : service.syncingFolderCount ? "sync" : "cloud_done"
    pillRightClickAction: function () {
        root.triggerPopout();
    }

    function resolveService() {
        service = pluginService && pluginId ? pluginService.getGlobalVar(pluginId, "service", null) : null;
        host = pluginService && pluginId ? pluginService.getGlobalVar(pluginId, "host", null) : null;
    }
    Component.onCompleted: resolveService()
    onPluginServiceChanged: resolveService()
    onPluginIdChanged: resolveService()
    Connections {
        target: root.pluginService
        function onGlobalVarChanged(id, name) {
            if (id === root.pluginId && (name === "service" || name === "host"))
                root.resolveService();
        }
    }
    PanelController {
        id: panelController
        service: root.service
    }
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            DankIcon {
                name: root.stateIcon
                size: root.iconSize
                color: root.service && root.service.folderProblemCount ? Theme.error : Theme.primary
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.service ? String(root.service.folderCount) : "-"
            }
        }
    }
    verticalBarPill: Component {
        DankIcon {
            name: root.stateIcon
            size: root.iconSize
            color: root.service && root.service.folderProblemCount ? Theme.error : Theme.primary
        }
    }
    popoutContent: Component {
        SyncthingPanelPopup {
            controller: panelController
            host: root.host
            pluginId: root.pluginId
            onWidthRequested: value => root.popoutWidth = value
        }
    }
}
