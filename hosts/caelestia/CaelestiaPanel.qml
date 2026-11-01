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
    // Read-only: the bar entry creates the controller before opening, and
    // creating it here mutated `views` inside this binding (binding loop).
    readonly property var controller: window && CaelestiaService.adapter && CaelestiaService.hasScreen(window.screen.name) ? CaelestiaService.views[window.screen.name] ?? null : null
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
        when: root.active && !!panel.item
        value: (root.content?.geometry.center || 0) + root.host.panels.anchors.topMargin + root.hostPadding / 2
        restoreMode: Binding.RestoreBindingOrValue
    }
    HyprlandFocusGrab {
        active: root.active
        windows: root.window ? [root.window] : []
        onCleared: root.close()
    }
    Loader {
        id: panel
        anchors.fill: parent
        active: !!root.controller && !!root.host
        sourceComponent: SyncshellPanelPopup {
            controller: root.controller
            owner: CaelestiaService
            availableWidth: root.host.panels.width - root.hostPadding
            availableHeight: root.host.panels.height - root.hostPadding
            // The bar entry owns the opening anchor; the loader completes this
            // item before it has a window, so the host state is not readable yet.
            anchorCenter: (root.controller.view.anchorCenter || 0) - root.host.panels.anchors.topMargin - root.hostPadding / 2
            onDismissed: root.close()
        }
    }
    function close() {
        CaelestiaService.pinOverview(window?.screen?.name || "", false);
        if (popouts)
            popouts.close();
    }
    Component.onCompleted: CaelestiaService.attach(entryPoint, settings)
}
