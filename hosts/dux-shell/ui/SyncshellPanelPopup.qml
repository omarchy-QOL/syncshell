import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.DCommon.Widgets
import qs.Modals.FileBrowser
import "../models/PanelModel.js" as Model
import "UiConstants.js" as UiConstants

FocusScope {
    id: root
    required property var controller
    property var host: null
    property var parentPopout: null
    property var closePopout: function () {}
    property string pluginId: "syncshell"
    property real mainWidth: UiConstants.CONTENT_WIDTH * Math.max(1, Theme.fontScale)
    property real sideWidth: 360 * Math.max(1, Theme.fontScale)
    property real triggerRowY: 0
    readonly property bool sideOpen: controller.form !== ""
    readonly property bool confirming: controller.confirmation !== null
    readonly property real screenWidth: parentPopout && parentPopout.screen ? parentPopout.screen.width : 1920
    readonly property real screenHeight: parentPopout && parentPopout.screen ? parentPopout.screen.height : 1080
    readonly property int barPosition: parentPopout ? parentPopout.effectiveBarPosition : 0
    readonly property real usableTop: Theme.spacingL + (barPosition === 0 && parentPopout ? parentPopout.storedBarThickness + parentPopout.storedBarSpacing * 2 : 0)
    readonly property real availableHeight: Math.max(140, screenHeight - (barPosition <= 1 && parentPopout ? parentPopout.storedBarThickness + parentPopout.storedBarSpacing * 2 : 0) - Theme.spacingL * 2)
    readonly property var sidePlacement: parentPopout ? Model.sideWindowPlacement(screenWidth, screenHeight, {
            x: parentPopout.alignedX,
            y: parentPopout.alignedY,
            width: parentPopout.alignedWidth
        }, sideWidth, sideWindow.implicitHeight, PopoutMetrics.contentPadding + triggerRowY, 0, Theme.spacingL, usableTop) : ({
            side: "left",
            x: 0,
            y: 0
        })

    implicitHeight: Math.min(availableHeight, mainPane.implicitHeight)

    // Hyprland moves the keyboard past the popout's focus grab only while the
    // popout releases it, so it does while a form is open, like DMS's own
    // surface modals. The form claims the keyboard with a brief exclusive
    // request (exclusive layers also take all pointer input), then stays
    // on-demand so the panel and the dismiss catcher keep their clicks.
    property bool claimingKeyboard: false
    function claimKeyboard() {
        releasePopoutKeyboard();
        claimingKeyboard = sideWindow.visible && !confirming;
        if (claimingKeyboard)
            keyboardClaim.restart();
    }
    function releasePopoutKeyboard() {
        if (parentPopout)
            parentPopout.customKeyboardFocus = sideWindow.visible && !confirming ? WlrKeyboardFocus.None : null;
    }
    Timer {
        id: keyboardClaim
        interval: 300
        onTriggered: root.claimingKeyboard = false
    }

    function closeInner() {
        if (picker.shouldBeVisible) {
            picker.close();
            return;
        }
        if (controller.confirmation)
            controller.cancelConfirmation();
        else if (controller.form)
            controller.closeForm();
        else
            closePopout();
    }

    function restoreFocus() {
        if (!parentPopout || !parentPopout.shouldBeVisible)
            return;
        if (confirming && confirmLoader.item)
            confirmLoader.item.selectCancel();
        else if (!sideOpen || !sidePane.focusContent())
            forceActiveFocus();
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            closeInner();
            event.accepted = true;
            return;
        }
        var item = root.Window.window ? root.Window.window.activeFocusItem : null;
        while (item && item !== root) {
            if ("cursorPosition" in item)
                return;
            item = item.parent;
        }
        if (event.isAutoRepeat || controller.busy || controller.confirmation || controller.form)
            return;
        var service = controller.service;
        switch (event.key) {
        case Qt.Key_R:
            if (service)
                service.rescanAllFolders();
            break;
        case Qt.Key_W:
            if (service)
                service.openWebUi();
            break;
        case Qt.Key_P:
            controller.requestServiceToggle(null);
            break;
        case Qt.Key_S:
            footerActions.openSettings();
            break;
        case Qt.Key_Q:
            closeInner();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    Keys.onPressed: event => handleKey(event)
    onSideOpenChanged: {
        if (sideOpen && controller.returnFocus && controller.returnFocus.mapToItem)
            triggerRowY = controller.returnFocus.mapToItem(root, 0, 0).y;
    }
    onConfirmingChanged: {
        claimKeyboard();
        Qt.callLater(restoreFocus);
    }
    Component.onCompleted: forceActiveFocus()

    Connections {
        target: root.parentPopout
        function onOpened() {
            Qt.callLater(root.restoreFocus);
        }
        function onPopoutClosed() {
            root.parentPopout.transientSurfaceTracker.closeAll();
        }
    }
    Connections {
        target: root.controller
        function onFocusRequested(target) {
            if (target && target.forceActiveFocus)
                target.forceActiveFocus();
            else
                root.forceActiveFocus();
        }
        function onDirectoryPickerRequested() {
            picker.open();
        }
    }
    // The surface modal sits on the overlay layer, above this popout; a plain
    // FileBrowserModal is a tiled window that the popout would cover.
    FileBrowserSurfaceModal {
        id: picker
        folderMode: true
        browserTitle: "Syncshell folder"
        parentPopout: root.parentPopout
        onOpened: if (root.parentPopout)
            root.parentPopout.transientSurfaceTracker.setActive(picker, true, picker.contentWindow)
        onFileSelected: path => root.controller.setDraft("path", path)
        onDialogClosed: {
            if (root.parentPopout)
                root.parentPopout.transientSurfaceTracker.unregister(picker);
            // The picker hands the popout its keyboard back; the form reclaims it.
            Qt.callLater(root.claimKeyboard);
            Qt.callLater(root.restoreFocus);
        }
        Component.onDestruction: if (root.parentPopout)
            root.parentPopout.transientSurfaceTracker.unregister(picker)
    }
    Connections {
        target: root.parentPopout ? root.parentPopout.transientSurfaceTracker : null
        function onCloseRequested() {
            if (picker.shouldBeVisible)
                picker.close();
        }
    }

    ColumnLayout {
        id: mainPane
        width: root.width
        height: root.height
        spacing: UiConstants.SECTION_SPACING
        DFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: body.implicitHeight
            contentHeight: body.implicitHeight
            clip: true
            ColumnLayout {
                id: body
                width: parent.width
                spacing: UiConstants.SECTION_SPACING
                Header {
                    Layout.fillWidth: true
                    controller: root.controller
                    iconStyle: root.host ? root.host.settings.values.iconStyle : "themed"
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.host ? root.host.error : ""
                    visible: text !== ""
                    textFormat: Text.PlainText
                    color: Theme.error
                }
                // Header, then a rule, then the body; FooterActions opens with
                // the second rule, as in Omarchy's three-part panel.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Theme.outlineWidth
                    color: Theme.outlineVariant
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingS
                    SharedWidgetTooltipButton {
                        text: "Folders (" + (root.controller.service ? root.controller.service.folders.length : 0) + ")"
                        checked: root.controller.tab === "folders"
                        onClicked: root.controller.tab = "folders"
                    }
                    SharedWidgetTooltipButton {
                        text: "Devices (" + (root.controller.service ? root.controller.service.remoteDevices().length : 0) + ")"
                        checked: root.controller.tab === "devices"
                        onClicked: root.controller.tab = "devices"
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                }
                // A stack sizes to the taller tab, so switching tabs keeps the
                // panel height like Omarchy's.
                StackLayout {
                    Layout.fillWidth: true
                    currentIndex: root.controller.tab === "folders" ? 0 : 1
                    BodyTabFolders {
                        Layout.fillWidth: true
                        controller: root.controller
                        parentPopout: root.parentPopout
                    }
                    BodyTabDevices {
                        Layout.fillWidth: true
                        controller: root.controller
                        parentPopout: root.parentPopout
                    }
                }
                BodyMore {
                    Layout.fillWidth: true
                    controller: root.controller
                }
            }
        }
        ColumnLayout {
            id: footer
            Layout.fillWidth: true
            spacing: UiConstants.SECTION_SPACING
            FooterActions {
                id: footerActions
                Layout.fillWidth: true
                controller: root.controller
                pluginId: root.pluginId
                onSettingsOpening: root.closePopout()
            }
            FooterShortcutHint {
                Layout.fillWidth: true
            }
            StyledText {
                Layout.fillWidth: true
                text: root.controller.error
                textFormat: Text.PlainText
                color: Theme.error
                visible: text !== ""
            }
        }
    }
    // Omarchy confirms over the dimmed panel rather than in a side form.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -PopoutMetrics.contentPadding
        visible: root.confirming
        radius: Theme.windowRadius
        color: Qt.rgba(0, 0, 0, Theme.scrimAlpha)
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
        }
        StyledRect {
            anchors.centerIn: parent
            width: root.width - Theme.spacingL * 2
            height: confirmLoader.implicitHeight + Theme.spacingL * 2
            radius: Theme.cornerRadiusL
            color: Theme.floatingSurfaceHigh
            Loader {
                id: confirmLoader
                active: root.confirming
                x: Theme.spacingL
                y: Theme.spacingL
                width: parent.width - Theme.spacingL * 2
                onLoaded: Qt.callLater(root.restoreFocus)
                sourceComponent: SharedDialogConfirm {
                    controller: root.controller
                }
            }
        }
    }
    // With the popout's focus grab released for the form, Hyprland dismisses
    // nothing on outside clicks; this catcher does, like the popout's own
    // background window, leaving the bar, popout and form clickable.
    PanelWindow {
        id: dismissCatcher
        screen: sideWindow.screen
        visible: sideWindow.visible
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "dms:plugins:syncshell:dismiss"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {
            item: catcherArea
            Region {
                item: barHole
                intersection: Intersection.Subtract
            }
            Region {
                item: popoutHole
                intersection: Intersection.Subtract
            }
            Region {
                item: formHole
                intersection: Intersection.Subtract
            }
        }
        Item {
            id: catcherArea
            anchors.fill: parent
        }
        Item {
            id: barHole
            readonly property real thickness: root.parentPopout ? root.parentPopout.storedBarThickness + root.parentPopout.storedBarSpacing * 2 : 0
            x: root.barPosition === 3 ? parent.width - thickness : 0
            y: root.barPosition === 1 ? parent.height - thickness : 0
            width: root.barPosition >= 2 ? thickness : parent.width
            height: root.barPosition >= 2 ? parent.height : thickness
        }
        Item {
            id: popoutHole
            x: root.parentPopout ? root.parentPopout.alignedX : 0
            y: root.parentPopout ? root.parentPopout.alignedY : 0
            width: root.parentPopout ? root.parentPopout.alignedWidth : 0
            height: root.parentPopout ? root.parentPopout.alignedHeight : 0
        }
        Item {
            id: formHole
            x: root.sidePlacement.x
            y: root.sidePlacement.y
            width: sideWindow.implicitWidth
            height: sideWindow.implicitHeight
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: root.closePopout()
        }
    }
    // DMS paints one popout rectangle at the requested size, so the side form
    // gets its own content-sized surface beside it, as Omarchy's does. The
    // popout's focus grab admits it as a transient surface.
    PanelWindow {
        id: sideWindow
        screen: root.parentPopout ? root.parentPopout.screen : null
        visible: root.sideOpen && !!root.parentPopout && root.parentPopout.shouldBeVisible
        color: "transparent"
        implicitWidth: root.sideWidth
        implicitHeight: Math.min(root.availableHeight, sidePane.implicitHeight)
        anchors {
            top: true
            left: true
        }
        margins {
            top: root.sidePlacement.y
            left: root.sidePlacement.x
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "dms:plugins:syncshell:form"
        WlrLayershell.keyboardFocus: !visible || root.confirming ? WlrKeyboardFocus.None : root.claimingKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
        onVisibleChanged: {
            if (root.parentPopout)
                root.parentPopout.transientSurfaceTracker.setActive(sideWindow, visible, visible ? sideWindow : null);
            root.claimKeyboard();
            if (visible)
                Qt.callLater(root.restoreFocus);
        }
        Component.onDestruction: if (root.parentPopout)
            root.parentPopout.transientSurfaceTracker.unregister(sideWindow)
        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => root.handleKey(event)
            BodyFormSideCard {
                id: sidePane
                anchors.fill: parent
                controller: root.controller
                parentPopout: root.parentPopout
                maximumHeight: root.availableHeight
                joinedEdge: root.sidePlacement.side === "left" ? "right" : root.sidePlacement.side === "right" ? "left" : ""
                joinedBottom: !!root.parentPopout && root.sidePlacement.y + sideWindow.implicitHeight <= root.parentPopout.alignedY + root.parentPopout.alignedHeight - Theme.windowRadius
            }
        }
    }
}
