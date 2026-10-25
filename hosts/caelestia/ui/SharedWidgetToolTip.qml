pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import Caelestia.Config
import qs.components
import qs.services

QQC.ToolTip {
    id: root
    // Popup items carry no screen; resolve tokens through the visual parent.
    readonly property Item tokens: parent
    delay: 500
    padding: tokens.Tokens.padding.medium
    width: Math.min(tokens.Tokens.font.body.small.pointSize * 36, label.implicitWidth + padding * 2)
    contentItem: StyledText {
        id: label
        text: root.text
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    background: StyledRect {
        color: Colours.palette.m3surfaceContainerHigh
        radius: root.tokens.Tokens.rounding.medium
    }
}
