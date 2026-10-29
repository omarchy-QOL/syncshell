import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets

RowLayout {
    property string label: ""
    property string value: ""
    property color valueColor: Theme.onSurface
    spacing: Theme.spacingS
    StyledText {
        text: label
        color: Theme.onSurfaceVariant
        textFormat: Text.PlainText
    }
    StyledText {
        text: value
        color: valueColor
        textFormat: Text.PlainText
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideMiddle
        wrapMode: Text.NoWrap
    }
}
