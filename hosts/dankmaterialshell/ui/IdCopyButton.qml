import QtQuick
import Quickshell.Io

SquareActionButton {
    id: root
    property string value: ""
    property bool copied: false
    property string error: ""
    iconName: copied ? "check" : "content_copy"
    help: error || (copied ? "Copied" : "Copy ID")
    busy: copy.running
    enabled: value !== ""
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
    Timer { id: reset; interval: 1800; onTriggered: root.copied = false }
}
