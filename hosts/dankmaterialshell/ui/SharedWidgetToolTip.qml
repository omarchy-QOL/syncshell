import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Item {
    id: root
    property string text: ""
    HoverHandler {
        id: hover
        enabled: root.text !== ""
    }
    ToolTip {
        visible: hover.hovered && root.text !== ""
        delay: 500
        width: Math.min(360, label.implicitWidth + Theme.spacingM * 2)
        padding: Theme.spacingM
        contentItem: StyledText {
            id: label
            text: root.text
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            maximumLineCount: 14
        }
        background: StyledRect {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
        }
    }
}
