pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components.controls
import qs.services
import "."

TextButton {
    id: root
    label.textFormat: Text.PlainText
    property bool busy: false
    property string caption: ""
    property string busyCaption: "Working..."
    property string help: ""
    property string feedback: ""
    property string copyValue: ""
    text: feedback || (busy ? busyCaption : caption)
    implicitWidth: Math.max(idleMetrics.width, busyMetrics.width, feedbackMetrics.width) + horizontalPadding * 2
    TextMetrics {
        id: idleMetrics
        font: root.font
        text: root.caption
    }
    TextMetrics {
        id: busyMetrics
        font: root.font
        text: root.busyCaption
    }
    TextMetrics {
        id: feedbackMetrics
        font: root.font
        text: root.copyValue ? "Copied" : ""
    }
    SyncshellToolTip {
        visible: (hover.hovered || root.activeFocus) && !!root.help
        text: root.help
    }
    HoverHandler {
        id: hover
        enabled: !!root.help
    }
    Timer {
        id: feedbackTimer
        interval: 2000
        onTriggered: root.feedback = ""
    }
    onCopyValueChanged: feedback = ""
    onClicked: if (copyValue) {
        Quickshell.clipboardText = copyValue;
        feedback = "Copied";
        feedbackTimer.restart();
    }
    disabled: busy
    enabled: !disabled && !busy
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
            if (!event.isAutoRepeat && !disabled && !busy)
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
