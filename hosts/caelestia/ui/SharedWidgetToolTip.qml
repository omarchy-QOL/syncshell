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
    // Keep the tip inside the panel window instead of cutting it at the edge.
    margins: tokens.Tokens.padding.small
    padding: tokens.Tokens.padding.medium
    width: Math.min(tokens.Tokens.font.body.small.pointSize * 36, label.implicitWidth + padding * 2)
    // The inactive tab page is transparent but still hovered; its tips stay hidden.
    property bool onHiddenPage: false
    function transparent(item) {
        for (let node = item; node; node = node.parent)
            if (node.opacity === 0)
                return true;
        return false;
    }
    onAboutToShow: onHiddenPage = transparent(parent)
    contentItem: StyledText {
        id: label
        visible: !root.onHiddenPage
        text: root.text
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    background: StyledRect {
        visible: !root.onHiddenPage
        color: Colours.palette.m3surfaceContainerHigh
        radius: root.tokens.Tokens.rounding.medium
    }
}
