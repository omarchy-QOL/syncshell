import QtQuick
import QtQuick.Layouts

RowLayout {
    required property var style
    property string title: ""
    signal canceled
    SharedWidgetNativeText {
        style: parent.style
        text: parent.title
        Layout.fillWidth: true
    }
    SharedWidgetBusyButton {
        style: parent.style
        text: "Cancel"
        onClicked: parent.canceled()
    }
}
