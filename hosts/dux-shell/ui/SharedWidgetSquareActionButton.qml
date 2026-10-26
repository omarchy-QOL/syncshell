import QtQuick
import QtQuick.Controls
import "UiConstants.js" as UiConstants

// Toolbar square action (add, share, link) with a busy state.
FocusScope {
    id: root
    property string iconName: ""
    property string help: ""
    property bool busy: false
    property bool danger: false
    property real size: UiConstants.CONTROL_HEIGHT
    signal clicked

    function activateKey(event) {
        if ([Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter].indexOf(event.key) < 0)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat && enabled && !busy)
            clicked();
    }
    Keys.onPressed: event => activateKey(event)
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    SharedWidgetTooltipActionButton {
        id: button
        focus: true
        anchors.fill: parent
        size: root.size
        iconName: root.busy ? "" : root.iconName
        help: root.help
        danger: root.danger
        handlesKeys: false
        enabled: root.enabled && !root.busy
        onClicked: root.clicked()
    }
    BusyIndicator {
        anchors.centerIn: parent
        width: root.size * 0.7
        height: width
        running: root.busy
        visible: root.busy
    }
}
