import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import "ui"
import "models/PanelModel.js" as Model
import "../../shared/Paths.js" as Paths

Scope {
    id: root
    required property var host
    readonly property var controller: host.controller
    readonly property var style: host.style
    readonly property bool sideVisible: controller.confirmationVisible || controller.formVisible || host.settings.opened
    property bool picking: false
    readonly property var bounds: Model.geometry(host.invokingScreen.width, host.invokingScreen.height, host.anchorRect, {
        width: style.panelWidth,
        height: mainPane.implicitHeight + style.margin * 2 + 12
    }, {
        width: style.formWidth,
        height: sidePane.implicitHeight + style.margin * 2 + 12,
        visible: sideVisible,
        offset: controller.formOffset
    }, host.edge, 10, 12)

    function registerFocus() {
        if (host.family !== "ii" || picking)
            return;
        GlobalFocusGrab.addDismissable(main);
        if (sideVisible)
            GlobalFocusGrab.addDismissable(side);
        else
            GlobalFocusGrab.removeDismissable(side);
    }
    function releaseFocus() {
        GlobalFocusGrab.removeDismissable(main);
        GlobalFocusGrab.removeDismissable(side);
    }
    onSideVisibleChanged: registerFocus()
    Component.onCompleted: {
        registerFocus();
        Qt.callLater(() => {
            if (!root.sideVisible)
                mainPane.forceActiveFocus();
        });
    }
    Component.onDestruction: releaseFocus()

    PanelWindow {
        id: main
        screen: root.host.invokingScreen
        anchors {
            top: true
            left: true
        }
        WlrLayershell.margins.left: root.bounds.main.x
        WlrLayershell.margins.top: root.bounds.main.y
        implicitWidth: root.bounds.main.width
        implicitHeight: root.bounds.main.height
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.namespace: "quickshell:syncshell"
        WlrLayershell.keyboardFocus: root.picking ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand
        Loader {
            id: mainSurface
            anchors.fill: parent
            anchors.margins: 6
            sourceComponent: root.style.surfaceComponent
            Binding {
                target: mainSurface.item
                property: "footerHeight"
                value: mainPane.footerHeight + root.style.margin + root.style.spacing / 2
            }
        }
        PanelPane {
            id: mainPane
            host: root.host
            anchors.fill: parent
            anchors.margins: root.style.margin + 6
        }
    }

    PanelWindow {
        id: side
        visible: root.sideVisible
        screen: root.host.invokingScreen
        anchors {
            top: true
            left: true
        }
        WlrLayershell.margins.left: root.bounds.side.x
        WlrLayershell.margins.top: root.bounds.side.y
        implicitWidth: root.bounds.side.width
        implicitHeight: root.bounds.side.height
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.namespace: "quickshell:syncshell-form"
        WlrLayershell.keyboardFocus: root.picking ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand
        Loader {
            anchors.fill: parent
            anchors.margins: 6
            sourceComponent: root.style.surfaceComponent
        }
        PanelPane {
            id: sidePane
            host: root.host
            side: true
            anchors.fill: parent
            anchors.margins: root.style.margin + 6
        }
    }

    HyprlandFocusGrab {
        active: root.host.family === "waffle" && !root.picking
        windows: root.sideVisible ? [main, side] : [main]
        onCleared: if (!root.picking)
            root.host.close()
    }
    Connections {
        target: GlobalFocusGrab
        function onDismissed() {
            if (root.host.family === "ii" && !root.picking)
                root.host.close();
        }
    }
    Connections {
        target: root.host.settings
        function onOpenedChanged() {
            if (!root.host.settings.opened)
                root.controller.restoreTrigger();
        }
    }
    DirectoryPicker {
        controller: root.controller
        parentWindow: side.contentItem.Window.window
        onOpening: {
            root.picking = true;
            root.releaseFocus();
        }
        onReturned: {
            root.picking = false;
            root.registerFocus();
        }
    }
}
