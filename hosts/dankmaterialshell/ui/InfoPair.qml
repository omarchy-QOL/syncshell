import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

RowLayout {
    property string label: ""
    property string value: ""
    property color valueColor: Theme.surfaceText
    spacing: Theme.spacingS
    StyledText { text: label; color: Theme.surfaceVariantText; textFormat: Text.PlainText }
    StyledText {
        text: value
        color: valueColor
        textFormat: Text.PlainText
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideMiddle
        maximumLineCount: 1
    }
}
