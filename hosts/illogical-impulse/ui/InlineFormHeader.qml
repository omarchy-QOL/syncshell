import QtQuick
import QtQuick.Layouts

RowLayout {
    required property var style
    property string title: ""
    signal canceled
    NativeText {
        style: parent.style
        text: parent.title
        Layout.fillWidth: true
    }
    BusyButton {
        style: parent.style
        text: "Cancel"
        onClicked: parent.canceled()
    }
}
