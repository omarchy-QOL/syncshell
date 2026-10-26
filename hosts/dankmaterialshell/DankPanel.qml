import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "controllers"
import "ui"
import "models/PanelModel.js" as Model

PluginComponent {
    id: root
    layerNamespacePlugin: "syncshell"
    popoutWidth: 384 * Math.max(1, Theme.fontScale) + Theme.spacingS * 2
    property var service: null
    property var host: null
    readonly property string iconVariant: Model.statusVariant(service)
    readonly property bool themedIcon: !host || host.settings.values.iconStyle !== "branded"
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
    // Hover shows a status tooltip like Omarchy's bar; it never opens the panel.
    function showTooltip(item, hovered) {
        var pill = item;
        while (pill && pill.popoutTarget === undefined)
            pill = pill.parent;
        if (!hovered || (pill && pill.popoutTarget && pill.popoutTarget.shouldBeVisible)) {
            if (tooltipLoader.item)
                tooltipLoader.item.hide();
            tooltipLoader.active = false;
            return;
        }
        tooltipLoader.active = true;
        var screen = root.parentScreen || Screen;
        var text = Model.barTooltip(root.service);
        if (root.isVertical) {
            var mid = item.mapToItem(null, item.width / 2, item.height / 2);
            var left = root.axis?.edge === "left";
            var x = left ? root.barThickness + root.barSpacing + Theme.spacingXS : screen.width - root.barThickness - root.barSpacing - Theme.spacingXS;
            tooltipLoader.item.show(text, x, mid.y, screen, left, !left);
        } else {
            var top = item.mapToItem(null, item.width / 2, 0);
            var bottom = root.axis?.edge === "bottom";
            var y = bottom ? screen.height - root.barThickness - root.barSpacing - Theme.spacingXS - (Theme.fontSizeSmall * 1.5 + Theme.spacingS * 2) : root.barThickness + root.barSpacing + Theme.spacingXS;
            tooltipLoader.item.show(text, top.x, y, screen, false, false);
        }
    }
    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DTooltip {}
    }
    horizontalBarPill: Component {
        SharedWidgetMonoIcon {
            id: pillIcon
            size: root.iconSize
            variant: root.iconVariant
            themed: root.themedIcon
            tint: Theme.onSurface
            HoverHandler {
                onHoveredChanged: root.showTooltip(pillIcon, hovered)
            }
        }
    }
    verticalBarPill: Component {
        SharedWidgetMonoIcon {
            id: pillIcon
            size: root.iconSize
            variant: root.iconVariant
            themed: root.themedIcon
            tint: Theme.onSurface
            HoverHandler {
                onHoveredChanged: root.showTooltip(pillIcon, hovered)
            }
        }
    }
    popoutContent: Component {
        SyncshellPanelPopup {
            controller: panelController
            host: root.host
            pluginId: root.pluginId
            onWidthRequested: value => root.popoutWidth = value
        }
    }
}
