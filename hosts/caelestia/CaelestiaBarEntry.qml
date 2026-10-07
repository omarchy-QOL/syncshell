pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Plugins
import Caelestia.Config
import qs.components
import qs.services
import "."

Item {
    id: root
    required property pluginEntryPoint entryPoint
    required property var settings
    readonly property var window: QsWindow.window
    readonly property string screenName: window?.screen?.name || ""
    readonly property var host: window ? ShellState.componentsFor(window.screen) : null
    implicitWidth: Tokens.font.icon.medium.pointSize + Tokens.padding.large
    implicitHeight: implicitWidth
    activeFocusOnTab: true

    function open() {
        var bar = host && host.bar;
        if (!bar)
            return;
        var center = root.mapToItem(bar, 0, height / 2).y;
        CaelestiaService.controller(window.screen.name).update({
            anchorCenter: center
        });
        bar.popouts.currentName = entryPoint.properties.name;
        bar.popouts.currentCenter = center;
        bar.popouts.hasCurrent = true;
    }
    MaterialIcon {
        anchors.centerIn: parent
        text: root.settings.icon
        color: CaelestiaService.adapter?.online ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        fontStyle: Tokens.font.icon.medium
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.open()
    }
    Keys.onPressed: event => {
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Space) && !event.isAutoRepeat) {
            open();
            event.accepted = true;
        }
    }
    Component.onCompleted: CaelestiaService.acquire(entryPoint, settings, root)
    Component.onDestruction: CaelestiaService.release(root)
}
