import QtQuick
import QtQuick.Layouts
import qs.Widgets

RowLayout {
    id: root
    property string title: ""
    signal cancelled
    StyledText {
        text: root.title
        textFormat: Text.PlainText
        font.weight: Font.Medium
        Layout.fillWidth: true
    }
    DankButton {
        text: "Cancel"
        onClicked: root.cancelled()
    }
}
