import QtQuick
import QtQuick.Controls
import qs.Widgets

FocusScope {
    id: root
    property string iconName: ""
    property string help: ""
    property bool busy: false
    signal clicked()

    function activateKey(event) {
        if ([Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter].indexOf(event.key) < 0)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat && enabled && !busy)
            clicked();
    }
    implicitWidth: button.width
    implicitHeight: button.height
    DankActionButton {
        id: button
        focus: true
        iconName: root.busy ? "" : root.iconName
        enabled: root.enabled && !root.busy
        onClicked: if (!root.busy) root.clicked()
        Keys.onPressed: event => root.activateKey(event)
    }
    BusyIndicator {
        anchors.centerIn: parent
        width: 22; height: 22
        running: root.busy
        visible: root.busy
    }
    SyncshellToolTip { anchors.fill: parent; text: root.help }
}
