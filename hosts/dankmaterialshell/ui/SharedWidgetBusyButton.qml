import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

FocusScope {
    id: root
    property string text: ""
    property string busyText: "Working"
    property bool busy: false
    property string help: ""
    property color textColor: Theme.surfaceText
    signal clicked

    function activateKey(event) {
        if ([Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter].indexOf(event.key) < 0)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat && enabled && !busy)
            clicked();
    }

    implicitWidth: Math.max(labelMetrics.width, busyMetrics.width) + Theme.spacingL * 2 + 20
    implicitHeight: button.height
    TextMetrics {
        id: labelMetrics
        text: root.text
        font.pixelSize: Theme.fontSizeMedium
    }
    TextMetrics {
        id: busyMetrics
        text: root.busyText
        font.pixelSize: Theme.fontSizeMedium
    }
    DankButton {
        id: button
        focus: true
        width: root.width
        text: root.busy ? root.busyText : root.text
        textColor: root.textColor
        enabled: root.enabled && !root.busy
        onClicked: if (!root.busy)
            root.clicked()
        Keys.onPressed: event => root.activateKey(event)
    }
    BusyIndicator {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        visible: root.busy
        running: root.busy
    }
    SharedWidgetToolTip {
        anchors.fill: parent
        text: root.help
    }
}
