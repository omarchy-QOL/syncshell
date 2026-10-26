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

    // Like DMS's own surface modals, the form holds the keyboard while it is
    // open: Hyprland moves focus past the popout's grab only while the popout
    // releases it. The popout's background window still dismisses outside
    // clicks. Re-claiming after another surface (the picker) took the keyboard
    // makes Hyprland focus the form again.
    property bool claimingKeyboard: false
    function claimKeyboard() {
        claimingKeyboard = false;
        releasePopoutKeyboard();
        if (sideWindow.visible && !confirming)
            keyboardClaim.restart();
    }
    function releasePopoutKeyboard() {
        if (parentPopout)
            parentPopout.customKeyboardFocus = sideWindow.visible && !confirming ? WlrKeyboardFocus.None : null;
    }
    Timer {
        id: keyboardClaim
        interval: 50
        onTriggered: root.claimingKeyboard = sideWindow.visible && !root.confirming
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
        WlrLayershell.keyboardFocus: visible && root.claimingKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
