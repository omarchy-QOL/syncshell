pragma ComponentBehavior: Bound

import QtQuick
import qs.components.controls
import qs.services

TextButton {
    id: root
    property bool busy: false
    property string caption: ""
    text: busy ? "Working..." : caption
    disabled: busy
    enabled: !disabled
    activeFocusOnTab: enabled
    border.width: activeFocus ? 2 : 0
    border.color: Colours.palette.m3primary
    Connections {
        target: root
        function onClicked() {
            if (root.isToggle)
                Qt.callLater(() => root.internalChecked = root.checked);
        }
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            event.accepted = true;
            if (!event.isAutoRepeat && !disabled)
                clicked();
        }
    }
    onActiveFocusChanged: if (activeFocus)
        ensureVisible()
    function ensureVisible() {
        var ancestor = parent;
        while (ancestor) {
            var viewport = ancestor as Flickable;
            if (viewport) {
                var position = mapToItem(viewport.contentItem, 0, 0).y;
                viewport.contentY = Math.max(0, Math.min(position, Math.max(viewport.contentY, position + height - viewport.height), viewport.contentHeight - viewport.height));
                break;
            }
            ancestor = ancestor.parent;
        }
    }
}
