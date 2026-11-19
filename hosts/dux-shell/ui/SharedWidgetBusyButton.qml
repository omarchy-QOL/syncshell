import QtQuick
import QtQuick.Controls
import qs.Common
import "UiConstants.js" as UiConstants

// Text action whose width covers both captions, so busy text never resizes it.
FocusScope {
    id: root
    property string text: ""
    property string busyText: "Working"
    property string iconName: ""
    property bool busy: false
    property string help: ""
    property bool primary: false
    property real controlHeight: UiConstants.CONTROL_HEIGHT
    signal clicked

    function activateKey(event) {
        if ([Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter].indexOf(event.key) < 0)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat && enabled && !busy)
            clicked();
    }
    Keys.onPressed: event => activateKey(event)
    implicitWidth: Math.max(button.implicitWidth, busyMetrics.advanceWidth + Theme.spacingM * 2 + (iconName ? Theme.fontSizeSmall + 4 + Theme.spacingXS : 0))
    implicitHeight: controlHeight
    TextMetrics {
        id: busyMetrics
        text: root.busyText
        font.pixelSize: Theme.fontSizeSmall
    }
    SharedWidgetTooltipButton {
        id: button
        focus: true
        anchors.fill: parent
        controlHeight: root.controlHeight
        text: root.busy ? root.busyText : root.text
        iconName: root.busy ? "" : root.iconName
        help: root.help
        primary: root.primary
        handlesKeys: false
        enabled: root.enabled && !root.busy
        onClicked: if (!root.busy)
            root.clicked()
    }
    BusyIndicator {
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter
        width: root.controlHeight * 0.6
        height: width
        visible: root.busy
        running: root.busy
    }
}
