import QtQuick
import Quickshell

SharedWidgetBusyButton {
    id: root
    required property var controller
    property string value: ""
    readonly property bool copied: value !== "" && controller.copiedId === value
    objectName: "copy-id-" + value
    text: copied ? "Copied" : "Copy ID"
    enabled: value !== ""
    help: value
    onClicked: {
        Quickshell.clipboardText = value;
        controller.recordCopy(value);
    }
}
