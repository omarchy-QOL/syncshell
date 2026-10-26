import QtQuick
import QtQuick.Layouts
import qs.DCommon.Widgets

RowLayout {
    id: root
    property string title: ""
    signal cancelled
    StyledText {
        text: root.title
        textFormat: Text.PlainText
        font.weight: Font.Medium
        Layout.fillWidth: true
        maximumLineCount: 1
        elide: Text.ElideRight
    }
    SharedWidgetTooltipButton {
        text: "Cancel"
        onClicked: root.cancelled()
    }
}
