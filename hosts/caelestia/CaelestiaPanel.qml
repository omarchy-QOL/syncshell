pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Caelestia.Config
import Caelestia.Plugins
import qs.services
import "."
import "ui"

FocusScope {
    id: root
    required property pluginEntryPoint entryPoint
    required property var settings
    readonly property var window: QsWindow.window
    readonly property var host: window ? ShellState.componentsFor(window.screen) : null
    readonly property var popouts: host?.bar?.popouts
    readonly property var controller: window && CaelestiaService.adapter && CaelestiaService.hasScreen(window.screen.name) ? CaelestiaService.controller(window.screen.name) : null
    property real openingCenter: 0
    property bool initialized: false
    readonly property real hostPadding: Tokens.padding.extraLargeIncreased
    readonly property bool active: !!popouts && popouts.hasCurrent && popouts.currentName === entryPoint.properties.entry
    readonly property SyncshellPanelPopup content: panel.item as SyncshellPanelPopup
    implicitWidth: content?.implicitWidth || 0
    implicitHeight: content?.implicitHeight || 0
    focus: true

    Binding {
        target: root.window
        property: "WlrLayershell.keyboardFocus"
        when: root.active
        value: WlrKeyboardFocus.OnDemand
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: root.popouts
        property: "currentCenter"
        when: root.active && root.initialized && !!panel.item
        value: (root.content?.geometry.center || 0) + root.host.panels.anchors.topMargin + root.hostPadding / 2
        restoreMode: Binding.RestoreBindingOrValue
    }
    HyprlandFocusGrab {
        active: root.active
        windows: root.window ? [root.window] : []
        onCleared: if (root.popouts)
            root.popouts.close()
    }
    Loader {
        id: panel
        anchors.fill: parent
        active: root.initialized && !!root.controller && !!root.host
        sourceComponent: SyncshellPanelPopup {
            controller: root.controller
            owner: CaelestiaService
            availableWidth: root.host.panels.width - root.hostPadding
            availableHeight: root.host.panels.height - root.hostPadding
            anchorCenter: root.openingCenter - root.host.panels.anchors.topMargin - root.hostPadding / 2
            onDismissed: root.popouts.close()
        }
    }
    Component.onCompleted: {
        CaelestiaService.attach(entryPoint, settings);
        openingCenter = popouts ? popouts.currentCenter : 0;
        initialized = true;
    }
}
