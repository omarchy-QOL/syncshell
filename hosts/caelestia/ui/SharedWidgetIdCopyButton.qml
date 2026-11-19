pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import "."

// Compact identifier copy chip; the identifier itself is never shown as a
// button caption.
IconTextButton {
    id: root
    property string value: ""
    property string caption: "ID"
    property string help: "Copy ID"
    property bool copied: false
    type: TextButton.Text
    horizontalPadding: Tokens.padding.small
    verticalPadding: 0
    icon: copied ? "check" : "content_copy"
    text: copied ? "Copied" : caption
    // Reserve the wider caption so feedback never resizes the row.
    implicitWidth: Math.max(captionMetrics.advanceWidth, copiedMetrics.advanceWidth) + iconLabel.implicitWidth + spacing + horizontalPadding * 2
    disabled: !value
    enabled: !disabled
    activeFocusOnTab: enabled
    border.width: activeFocus ? 2 : 0
    border.color: Colours.palette.m3primary
    Accessible.name: help
    TextMetrics {
        id: captionMetrics
        font: root.label.font
        text: root.caption
    }
    TextMetrics {
        id: copiedMetrics
        font: root.label.font
        text: "Copied"
    }
    SharedWidgetToolTip {
        visible: root.hovered || root.activeFocus
        text: root.copied ? "Copied" : root.help
    }
    Timer {
        id: reset
        interval: 2000
        onTriggered: root.copied = false
    }
    onValueChanged: copied = false
    onClicked: {
        Quickshell.clipboardText = value;
        copied = true;
        reset.restart();
    }
    Keys.onPressed: event => {
        if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)) {
            event.accepted = true;
            if (!event.isAutoRepeat && enabled)
                clicked();
        }
    }
}
