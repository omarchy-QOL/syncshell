pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.components.controls
import qs.services

// Caelestia's outlined field floats its placeholder into the border, where it
// collides with Omarchy's caption above the field; this keeps the hint inside.
StyledTextField {
    id: root
    property string hint: ""
    placeholderText: ""
    StyledText {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.leftPadding
        anchors.rightMargin: root.rightPadding
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.text && !root.preeditText
        text: root.hint
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Colours.palette.m3outline
        font: root.font
    }
}
