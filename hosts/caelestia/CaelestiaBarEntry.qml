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
        CaelestiaService.controller(screenName).update({
            anchorCenter: root.mapToItem(bar, 0, height / 2).y
        });
        show();
        CaelestiaService.pinOverview(screenName, true);
    }
    function show() {
        // While the overview is current its panel binds the center; writing it
        // here would override that binding and shift the panel.
        if (popouts.currentName !== Model.overviewPopout)
            popouts.currentCenter = CaelestiaService.controller(screenName).view.anchorCenter;
        popouts.currentName = Model.overviewPopout;
        popouts.hasCurrent = true;
    }
    // The host closes popouts when the pointer leaves them, and hovering
    // another bar icon swaps in its popout. Keep an explicitly opened overview
    // until it is dismissed, returning to it when a hover popout closes.
    Connections {
        target: root.popouts
        function onHasCurrentChanged() {
            if (!root.popouts.hasCurrent && root.pinned)
                root.show();
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
        x: root.width + root.Tokens.spacing.medium
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
