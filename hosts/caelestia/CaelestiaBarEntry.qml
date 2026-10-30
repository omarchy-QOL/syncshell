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
            if (root.popouts.hasCurrent) {
                root.reshowPending = false;
                return;
            }
            if (!root.pinned)
                return;
            // The host wrapper binds focus to hasCurrent, so re-showing takes
            // keyboard focus from the overview; hand it back to the same item.
            if (root.popouts.currentName === Model.overviewPopout) {
                const focused = root.Window.window?.activeFocusItem;
                root.show();
                if (focused)
                    focused.forceActiveFocus();
                return;
            }
            // Gliding over from a hover popout bends the host's background,
            // and its blob does not redraw when it snaps back to rest, which
            // left the background 2 px off. Wait for the close to finish and
            // open fresh instead.
            root.reshowPending = true;
            root.reshowWhenClosed();
        }
    }
    property bool reshowPending: false
    readonly property var popoutsWrapper: host?.panels?.popoutsWrapper ?? null
    function reshowWhenClosed() {
        if (reshowPending && pinned && popoutsWrapper && popoutsWrapper.offsetScale >= 1) {
            reshowPending = false;
            show();
        }
    }
    Connections {
        target: root.popoutsWrapper
        function onOffsetScaleChanged() {
            root.reshowWhenClosed();
        }
    }
    readonly property bool svgIcon: root.settings.icon === "themed" || root.settings.icon === "branded"
    readonly property string iconVariant: Model.statusVariant(CaelestiaService.adapter)
    readonly property string iconRoot: CaelestiaService.adapter?.bundleRoot ?? ""
    readonly property color iconColour: CaelestiaService.adapter?.online ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
    // Legacy glyph settings keep working.
    MaterialIcon {
        anchors.centerIn: parent
        visible: !root.svgIcon
        text: root.settings.icon
        color: root.iconColour
        fontStyle: Tokens.font.icon.medium
    }
    SharedWidgetMonoIcon {
        anchors.centerIn: parent
        width: Tokens.font.icon.medium.pointSize * 1.4
        height: width
        visible: root.settings.icon === "themed"
        source: visible ? Model.statusIconUrl(root.iconRoot, root.iconVariant, true) : ""
        tint: root.iconColour
    }
    Image {
        anchors.centerIn: parent
        width: Tokens.font.icon.medium.pointSize * 1.4
        height: width
        visible: root.settings.icon === "branded"
        source: visible ? Model.statusIconUrl(root.iconRoot, root.iconVariant, false) : ""
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        smooth: true
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
