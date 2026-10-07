pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import Caelestia.Config
import qs.components
import qs.services

QQC.ToolTip {
    id: root
    delay: 500
    padding: Tokens.padding.medium
    width: Math.min(Tokens.font.body.small.pointSize * 36, label.implicitWidth + padding * 2)
    contentItem: StyledText {
        id: label
        text: root.text
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    background: StyledRect {
        color: Colours.palette.m3surfaceContainerHigh
        radius: Tokens.rounding.medium
    }
}
