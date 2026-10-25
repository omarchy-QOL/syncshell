import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

RowLayout {
    id: root
    property string label: ""
    property string value: ""
    StyledText {
        text: root.label
        textFormat: Text.PlainText
        color: Colours.palette.m3onSurfaceVariant
    }
    StyledText {
        Layout.fillWidth: true
        text: root.value
        textFormat: Text.PlainText
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
    }
}
