import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import "../models/PanelNavigation.js" as Navigation

FocusScope {
    id: root
    required property var host
    property bool side: false
    property string pendingReveal: ""
    readonly property var controller: host.controller
    readonly property var style: host.style
    readonly property alias bodyItem: body.item
    readonly property alias scrollItem: scroll
    readonly property real footerHeight: footer.visible ? footer.implicitHeight : 0
    readonly property bool covered: !side && (controller.formVisible || controller.confirmationVisible || host.settings.opened)
    implicitHeight: body.implicitHeight + footerHeight + (footer.visible ? style.spacing : 0)
    objectName: side ? "side-pane" : "panel"
    focus: true

    function reveal(item) {
        if (!item || !Navigation.contains(scroll.contentItem, item)) return;
        Qt.callLater(() => {
            if (!item) return;
            var point = item.mapToItem(scroll.contentItem, 0, 0);
            if (point.y < scroll.contentY) scroll.contentY = point.y;
            else if (point.y + item.height > scroll.contentY + scroll.height)
                scroll.contentY = point.y + Math.min(item.height, scroll.height) - scroll.height;
            scroll.contentY = Math.max(0, Math.min(scroll.contentY, Math.max(0, scroll.contentHeight - scroll.height)));
        });
    }
    function focusItem(item) {
        if (!item) return;
        if (typeof item.focusControl === "function") item.focusControl();
        else item.forceActiveFocus();
        reveal(item);
    }
    function restore(key) {
        var item = Navigation.find(root, key);
        if (item) focusItem(item);
        else if (!side && key === controller.triggerKey) {
            focusItem(Navigation.find(root, controller.tab === "devices" ? "devices" : "folder") || root);
        }
    }
    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            if (host.settings.opened && !controller.selector && !controller.confirmationVisible)
                host.settings.opened = false;
            else controller.handleEscape();
            event.accepted = true;
            return;
        }
        if (controller.selector || event.modifiers !== Qt.NoModifier) return;
        var focused = root.Window.window ? root.Window.window.activeFocusItem : null;
        if (focused && typeof focused.cursorPosition !== "undefined") return;
        var dx = event.key === Qt.Key_Left || event.key === Qt.Key_H ? -1
            : event.key === Qt.Key_Right || event.key === Qt.Key_L ? 1 : 0;
        var dy = event.key === Qt.Key_Up || event.key === Qt.Key_K ? -1
            : event.key === Qt.Key_Down || event.key === Qt.Key_J ? 1 : 0;
        if (dx || dy) {
            if (covered) return;
            focusItem(Navigation.move(root, focused, dx, dy));
            event.accepted = true;
            return;
        }
        if (event.isAutoRepeat || covered || side) return;
        if (event.key === Qt.Key_R) host.service.refreshStatus();
        else if (event.key === Qt.Key_W) host.service.openWebUi();
        else if (event.key === Qt.Key_S) host.service.rescanAllFolders();
        else if (event.key === Qt.Key_P && controller.tab === "folders" && controller.folder && !controller.blocked) {
            var folder = controller.folder;
            controller.ask(folder.paused ? "folder.resume" : "folder.pause", {folderId: folder.id},
                (folder.paused ? "Resume " : "Pause ") + (folder.label || folder.id) + "?", folder.path);
        } else if (event.key === Qt.Key_Q) host.close();
        else return;
        event.accepted = true;
    }
    Keys.priority: Keys.AfterItem
    Keys.onPressed: event => handleKey(event)
    ColumnLayout {
        anchors.fill: parent
        spacing: root.style.spacing
        Flickable {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            onContentHeightChanged: returnToBounds()
            ScrollBar.vertical: bar.item as ScrollBar
            Loader { id: bar; sourceComponent: root.style.scrollBar }
            Loader {
                id: body
                width: scroll.width
                sourceComponent: root.side ? sideBody : mainBody
            }
        }
        Loader {
            id: footer
            Layout.fillWidth: true
            visible: !root.side
            active: visible
            sourceComponent: ColumnLayout {
                FooterActions { host: root.host; Layout.fillWidth: true }
                FooterShortcutHint { style: root.style; Layout.fillWidth: true }
            }
        }
    }
    Component { id: mainBody; SyncshellPanelMain { host: root.host } }
    Component { id: sideBody; BodyFormSideCard { host: root.host } }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() {
            if (root.Window.window) root.reveal(root.Window.window.activeFocusItem);
        }
    }
    Connections {
        target: root.controller
        function onFocusRequested(key) { root.restore(key); }
        function onRevealRequested(key) {
            if (!root.side) { root.pendingReveal = key; revealTimer.restart(); }
        }
    }
    Timer {
        id: revealTimer
        interval: 32
        onTriggered: {
            var target = Navigation.find(root, root.pendingReveal);
            if (target) {
                root.focusItem(target);
                root.pendingReveal = "";
            }
        }
    }
    Timer {
        interval: 33
        running: !root.side && root.visible && root.controller.focusTrigger !== null
        repeat: true
        onTriggered: {
            var trigger = root.controller.focusTrigger;
            if (trigger && Navigation.contains(root, trigger) && trigger.visible)
                root.controller.formOffset = Math.max(0, trigger.mapToItem(root, 0, 0).y);
        }
    }
}
