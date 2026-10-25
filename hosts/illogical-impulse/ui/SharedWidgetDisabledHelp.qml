import QtQuick
import QtQuick.Window

Item {
    id: root
    required property Item control
    required property var style
    property string text: ""
    property bool inView: false
    objectName: control.objectName + "-disabled-help"
    parent: control.Window.window ? control.Window.window.contentItem : null
    width: control.width
    height: control.height
    visible: control.visible && !control.enabled && text !== "" && inView
    function place() {
        if (!parent) return;
        var point = control.mapToItem(parent, 0, 0);
        x = point.x;
        y = point.y;
        inView = true;
        for (let node = control.parent; node; node = node.parent) {
            if (!node.clip) continue;
            let local = control.mapToItem(node, 0, 0);
            if (local.x < 0 || local.y < 0 || local.x + width > node.width || local.y + height > node.height)
                inView = false;
        }
    }
    HoverHandler { id: hover }
    Loader {
        id: tip
        objectName: root.control.objectName + "-disabled-tooltip"
        active: root.visible
        sourceComponent: root.style.toolTip
        Binding { target: tip.item; property: "text"; value: root.text }
        Binding { target: tip.item; property: "visible"; value: root.visible && hover.hovered }
    }
    Timer {
        interval: 33
        running: root.control.visible && !root.control.enabled && root.text !== ""
        repeat: true
        onTriggered: root.place()
    }
    Component.onCompleted: place()
}
