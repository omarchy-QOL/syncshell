import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.syncshell as Syncshell
import "controllers"
import "ui/ii" as Material
import "ui/waffle" as Waffle

Scope {
    id: root
    property bool enabled: true
    property bool opened: false
    property var invokingScreen: null
    property rect anchorRect: Qt.rect(0, 0, 0, 0)
    property string edge: "top"
    property Item trigger: null
    readonly property string family: Config.options.panelFamily
    property string presentationFamily: "ii"
    readonly property alias paletteController: paletteController
    readonly property alias service: service
    readonly property alias controller: controller
    readonly property alias settings: settings
    readonly property var style: presentation.item

    function close() {
        openTimer.stop();
        controller.presentationActive = false;
        opened = false;
        if (trigger)
            trigger.forceActiveFocus();
    }

    function toggle(item) {
        if (!enabled || !Config.ready || GlobalStates.screenLocked)
            return;
        if (opened || openTimer.running) {
            close();
            return;
        }
        var window = item.QsWindow.window;
        if (!window || !window.screen)
            return;
        invokingScreen = window.screen;
        var point = item.mapToGlobal(0, 0);
        anchorRect = Qt.rect(point.x - invokingScreen.x, point.y - invokingScreen.y, item.width, item.height);
        edge = family === "waffle" ? (Config.options.waffles.bar.bottom ? "bottom" : "top") : Config.options.bar.vertical ? (Config.options.bar.bottom ? "right" : "left") : Config.options.bar.bottom ? "bottom" : "top";
        trigger = item;
        var nativePanelOpen = family === "waffle" && (GlobalStates.sidebarLeftOpen || GlobalStates.sidebarRightOpen);
        if (family === "waffle") {
            GlobalStates.sidebarLeftOpen = false;
            GlobalStates.sidebarRightOpen = false;
        }
        // The pinned WBarAttachedPanelContent releases its local grab after
        // its 150 ms closing animation. Acquire ours on the following frame.
        openTimer.interval = nativePanelOpen ? 170 : 0;
        openTimer.restart();
    }

    function shutdown() {
        close();
        enabled = false;
        service.core.terminate();
    }

    onFamilyChanged: {
        close();
        Qt.callLater(() => presentationFamily = family);
    }
    onEnabledChanged: if (!enabled)
        close()
    Component.onCompleted: {
        presentationFamily = family;
        if (Syncshell.Registry.owner && Syncshell.Registry.owner !== root)
            Syncshell.Registry.owner.shutdown();
        Syncshell.Registry.owner = root;
    }
    Component.onDestruction: {
        shutdown();
        if (Syncshell.Registry.owner === root)
            Syncshell.Registry.owner = null;
    }

    IpcHandler {
        target: "syncshell"
        function enable(): void {
            root.enabled = true;
        }
        function disable(): void {
            root.shutdown();
        }
    }
    Timer {
        id: openTimer
        onTriggered: {
            if (root.enabled && !GlobalStates.screenLocked && Quickshell.screens.indexOf(root.invokingScreen) >= 0) {
                controller.presentationActive = true;
                root.opened = true;
                controller.reopen();
            }
        }
    }
    IllogicalService {
        id: service
        active: root.enabled && Config.ready && settings.ready
        monochromeIcon: settings.values.monochrome
        probeIntervalSeconds: settings.values.probeIntervalSeconds
        refreshIntervalSeconds: settings.values.refreshIntervalSeconds
    }
    PanelController {
        id: controller
        service: service
        onCloseRequested: root.close()
    }
    SettingsController {
        id: settings
        service: service
    }
    ThemePaletteController {
        id: paletteController
        service: service
        settings: settings
        palette: root.style ? root.style.palette : ({})
    }
    Loader {
        id: presentation
        sourceComponent: root.presentationFamily === "waffle" ? waffleStyle : materialStyle
    }
    Component {
        id: materialStyle
        Material.NativeStyle {}
    }
    Component {
        id: waffleStyle
        Waffle.NativeStyle {}
    }
    Loader {
        active: root.opened && root.style !== null
        onActiveChanged: {
            if (active)
                setSource(Qt.resolvedUrl("IllogicalPanel.qml"), {
                    host: root
                });
            else
                source = "";
        }
    }
    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked)
                root.close();
        }
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen)
                root.close();
        }
        function onSidebarLeftOpenChanged() {
            if (root.family === "waffle" && GlobalStates.sidebarLeftOpen)
                root.close();
        }
        function onSidebarRightOpenChanged() {
            if (root.family === "waffle" && GlobalStates.sidebarRightOpen)
                root.close();
        }
    }
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.invokingScreen && Quickshell.screens.indexOf(root.invokingScreen) < 0)
                root.close();
        }
    }
}
