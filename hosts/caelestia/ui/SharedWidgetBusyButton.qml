pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components.controls
import qs.services
import "."

// Tonal by default like the other shell controls; `primary` fills the main
// action. An optional icon leads the caption, as in Omarchy.
IconTextButton {
    id: root
    label.textFormat: Text.PlainText
    property bool primary: false
    type: primary ? TextButton.Filled : TextButton.Tonal
    iconLabel.visible: icon !== "" && !busy
    property bool busy: false
    property string caption: ""
    // Caps the caption width; longer captions end with an ellipsis.
    property real maxCaptionWidth: -1
    property string busyCaption: "Working..."
    property string help: ""
    property string feedback: ""
    property string copyValue: ""
    text: feedback || (busy ? busyCaption : maxCaptionWidth > 0 ? elideMetrics.elidedText : caption)
    implicitWidth: Math.max(maxCaptionWidth > 0 ? Math.min(idleMetrics.width, maxCaptionWidth) : idleMetrics.width, busyMetrics.width, feedbackMetrics.width) + (icon !== "" ? iconLabel.implicitWidth + spacing : 0) + horizontalPadding * 2
    TextMetrics {
        id: elideMetrics
        font: root.font
        text: root.caption
        elide: Text.ElideRight
        elideWidth: root.maxCaptionWidth
    }
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
    SharedWidgetToolTip {
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
            let viewport = ancestor as Flickable;
            if (viewport) {
                let position = mapToItem(viewport.contentItem, 0, 0).y;
                viewport.contentY = Math.max(0, Math.min(position, Math.max(viewport.contentY, position + height - viewport.height), viewport.contentHeight - viewport.height));
                break;
            }
            ancestor = ancestor.parent;
        }
    }
}
