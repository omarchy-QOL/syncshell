pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Plugins
import Caelestia.Config
import qs.components
import qs.services
import "."
import "ui"
import "models/PanelModel.js" as Model

// Omarchy keeps its bar button inside OmarchyPanel; Caelestia's manifest
// needs a separate bar-entry entry point next to the popout.
Item {
    id: root
    required property pluginEntryPoint entryPoint
    required property var settings
    readonly property var window: QsWindow.window
    readonly property string screenName: window?.screen?.name || ""
    readonly property var host: window ? ShellState.componentsFor(window.screen) : null
    readonly property var popouts: host?.bar?.popouts ?? null
    readonly property bool overviewOpen: !!popouts && popouts.hasCurrent && popouts.currentName === Model.overviewPopout
    readonly property bool pinned: !!CaelestiaService.pinnedOverviews[screenName]
    implicitWidth: Tokens.font.icon.medium.pointSize + Tokens.padding.large
    implicitHeight: implicitWidth
    activeFocusOnTab: true

    // The SDK opens popouts whose entry matches the bar id on hover, so the
    // overview uses another name and opens only from here.
    function toggle() {
        var bar = host && host.bar;
        if (!bar)
            return;
        if (overviewOpen) {
            CaelestiaService.pinOverview(screenName, false);
            popouts.hasCurrent = false;
            return;
        }
        var center = root.mapToItem(bar, 0, height / 2).y;
        CaelestiaService.controller(screenName).update({
            anchorCenter: center
        });
        popouts.currentCenter = center;
        popouts.currentName = Model.overviewPopout;
        popouts.hasCurrent = true;
        CaelestiaService.pinOverview(screenName, true);
    }
    // Hover elsewhere on the drawer clears the host popout; keep an explicitly
    // opened overview until it is dismissed or another popout takes over.
    Connections {
        target: root.popouts
        function onHasCurrentChanged() {
            if (!root.popouts.hasCurrent && root.pinned && root.popouts.currentName === Model.overviewPopout)
                root.popouts.hasCurrent = true;
        }
        function onCurrentNameChanged() {
            if (root.popouts.currentName !== Model.overviewPopout)
                CaelestiaService.pinOverview(root.screenName, false);
        }
    }
    MaterialIcon {
        anchors.centerIn: parent
        text: root.settings.icon
        color: CaelestiaService.adapter?.online ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        fontStyle: Tokens.font.icon.medium
    }
    HoverHandler {
        id: hover
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.toggle()
    }
    SharedWidgetToolTip {
        x: root.width + Tokens.spacing.medium
        y: (root.height - height) / 2
        visible: hover.hovered && !root.overviewOpen
        text: Model.barTooltip(CaelestiaService.adapter)
    }
    Keys.onPressed: event => {
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Space) && !event.isAutoRepeat) {
            toggle();
            event.accepted = true;
        }
    }
    Component.onCompleted: CaelestiaService.acquire(entryPoint, settings, root)
    Component.onDestruction: CaelestiaService.release(root)
}
