import QtQuick
import Quickshell.Io
import qs.Common
import "UiConstants.js" as UiConstants

// Compact "copy ID" chip as in Omarchy: icon plus a short caption, never the
// ID. Without a caption it is the square icon button Omarchy puts beside names.
SharedWidgetTooltipButton {
    id: root
    property string value: ""
    property string caption: "ID"
    property string helpText: "Copy ID"
    property bool copied: false
    property string error: ""
    controlHeight: UiConstants.SMALL_CONTROL_HEIGHT
    flat: caption !== ""
    iconName: copied ? "check" : "content_copy"
    text: caption === "" ? "" : copied ? "Copied" : caption
    help: error || (copied ? "Copied" : helpText)
    enabled: value !== "" && !copy.running
    implicitWidth: caption === "" ? controlHeight : Math.max(captionMetrics.advanceWidth, copiedMetrics.advanceWidth) + Theme.fontSizeSmall + 4 + Theme.spacingXS + Theme.spacingM * 2
    TextMetrics {
        id: captionMetrics
        text: root.caption
        font.pixelSize: Theme.fontSizeSmall
    }
    TextMetrics {
        id: copiedMetrics
        text: "Copied"
        font.pixelSize: Theme.fontSizeSmall
    }
    onValueChanged: copied = false
    onClicked: {
        error = "";
        copy.command = ["dms", "cl", "copy", value];
        copy.running = true;
    }
    Process {
        id: copy
        onExited: function (code) {
            root.copied = code === 0;
            root.error = code === 0 ? "" : "Could not copy the ID";
            reset.restart();
        }
    }
    Timer {
        id: reset
        interval: UiConstants.COPY_FEEDBACK_MS
        onTriggered: root.copied = false
    }
}
