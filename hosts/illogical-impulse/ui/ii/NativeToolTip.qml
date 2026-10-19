import QtQuick
import qs.modules.common
import qs.modules.common.widgets

StyledToolTip {
    id: root
    background: StyledRectangle {
        color: Appearance.colors.colTooltip
        radius: Appearance.rounding.verysmall
    }
    contentItem: StyledText {
        text: root.text
        textFormat: Text.PlainText
        font: root.font
        color: Appearance.colors.colOnTooltip
        wrapMode: Text.Wrap
    }
}
