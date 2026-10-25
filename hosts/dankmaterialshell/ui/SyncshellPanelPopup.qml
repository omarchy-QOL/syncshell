import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import qs.Common
import qs.Widgets
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
    property string side: "right"
    property real originalTriggerX: 0
    property real originalTriggerY: 0
    property real mainX: 0
    property real mainTop: 0
    property real triggerRowY: 0
    property bool anchored: false
    readonly property bool sideOpen: controller.form !== "" || controller.confirmation !== null
    readonly property real screenWidth: parentPopout && parentPopout.screen ? parentPopout.screen.width : 1920
    readonly property real screenHeight: parentPopout && parentPopout.screen ? parentPopout.screen.height : 1080
    readonly property int barPosition: parentPopout ? parentPopout.effectiveBarPosition : 0
    readonly property real usableTop: Theme.spacingL + (barPosition === 0 && parentPopout ? parentPopout.storedBarThickness + parentPopout.storedBarSpacing * 2 : 0)
    readonly property real availableHeight: Math.max(140, screenHeight - (barPosition <= 1 && parentPopout ? parentPopout.storedBarThickness + parentPopout.storedBarSpacing * 2 : 0) - Theme.spacingL * 2)
    readonly property real sideExtra: sideOpen && side !== "stack" ? sideWidth + Theme.spacingM : 0
    readonly property real wantedWidth: Math.min(screenWidth - Theme.spacingL * 2, mainWidth + sideExtra + Theme.spacingS * 2)
    // DMS draws main and side form on one popout surface, so a form anchored
    // at its trigger row left an empty band above it; align it to the top.
    readonly property var panes: Model.paneLayout(mainPane.implicitHeight, sidePane.implicitHeight, availableHeight, 0, sideOpen, side === "stack", barPosition, mainTop, Theme.spacingM, footer.implicitHeight)
    signal widthRequested(real value)

    implicitHeight: panes.height

    function captureAnchor() {
        if (!parentPopout || !parentPopout.shouldBeVisible || anchored)
            return;
        mainX = parentPopout.alignedX + (sideOpen && side === "left" ? sideExtra : 0);
        mainTop = parentPopout.alignedY - usableTop;
        originalTriggerX = parentPopout.triggerX;
        originalTriggerY = parentPopout.triggerY;
        anchored = true;
    }

    function updatePlacement() {
        captureAnchor();
        if (sideOpen)
            side = Model.sidePlacement(screenWidth, mainX, mainWidth + Theme.spacingS * 2, sideWidth, Theme.spacingM, Theme.spacingL);
        if (parentPopout && anchored) {
            if (barPosition === 0 || barPosition === 1)
                parentPopout.triggerX = mainX - (side === "left" ? sideExtra : 0) + wantedWidth / 2 - parentPopout.triggerWidth / 2;
            else if (sideOpen)
                parentPopout.triggerY = usableTop + panes.top + (panes.height + Theme.spacingS * 2) / 2;
            else
                parentPopout.triggerY = originalTriggerY;
        }
        widthRequested(wantedWidth);
    }

    function closeInner() {
        if (parentPopout && parentPopout.transientSurfaceTracker.active) {
            parentPopout.transientSurfaceTracker.closeAll();
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
        if (!sideOpen || !sidePane.focusContent())
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
        if (sideOpen && parentPopout)
            mainTop = parentPopout.alignedY - usableTop;
        if (sideOpen && controller.returnFocus && controller.returnFocus.mapToItem)
            triggerRowY = controller.returnFocus.mapToItem(mainPane, 0, 0).y;
        updatePlacement();
    }
    onScreenWidthChanged: updatePlacement()
    onPanesChanged: updatePlacement()
    onMainWidthChanged: updatePlacement()
    onParentPopoutChanged: Qt.callLater(updatePlacement)
    Component.onCompleted: forceActiveFocus()

    Connections {
        target: root.parentPopout
        function onOpened() {
            root.anchored = false;
            root.captureAnchor();
            root.updatePlacement();
            Qt.callLater(root.restoreFocus);
        }
        function onPopoutClosed() {
            if (root.anchored) {
                root.parentPopout.triggerX = root.originalTriggerX;
                root.parentPopout.triggerY = root.originalTriggerY;
            }
            root.anchored = false;
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
    FileBrowserModal {
        id: picker
        folderMode: true
        browserTitle: "Syncshell folder"
        onVisibleChanged: {
            if (root.parentPopout)
                root.parentPopout.transientSurfaceTracker.setActive(picker, visible, visible ? picker : null);
        }
        onFileSelected: path => {
            root.controller.setDraft("path", path);
            close();
        }
        onDialogClosed: Qt.callLater(root.restoreFocus)
        Component.onDestruction: if (root.parentPopout)
            root.parentPopout.transientSurfaceTracker.unregister(picker)
    }
    Connections {
        target: root.parentPopout ? root.parentPopout.transientSurfaceTracker : null
        function onCloseRequested() {
            if (picker.visible)
                picker.close();
        }
    }

    ColumnLayout {
        id: mainPane
        x: root.sideOpen && root.side === "left" ? root.sideWidth + Theme.spacingM : 0
        y: root.panes.mainY
        width: Math.min(root.mainWidth, root.width)
        height: root.panes.mainHeight
        spacing: UiConstants.SECTION_SPACING
        DankFlickable {
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
                    implicitHeight: 1
                    color: Theme.outline
                    opacity: 0.4
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
                BodyTabFolders {
                    Layout.fillWidth: true
                    controller: root.controller
                    parentPopout: root.parentPopout
                    visible: root.controller.tab === "folders"
                }
                BodyTabDevices {
                    Layout.fillWidth: true
                    controller: root.controller
                    parentPopout: root.parentPopout
                    visible: root.controller.tab === "devices"
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
    BodyFormSideCard {
        id: sidePane
        controller: root.controller
        parentPopout: root.parentPopout
        visible: root.sideOpen
        width: root.side === "stack" ? Math.min(root.mainWidth, root.width) : root.sideWidth
        maximumHeight: root.availableHeight
        height: root.panes.sideHeight
        x: root.side === "right" ? mainPane.width + Theme.spacingM : 0
        y: root.panes.sideY
    }
}
