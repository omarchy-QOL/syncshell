pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Caelestia.Config
import qs.components
import qs.services
import "."

// Omarchy's forced choice when the saved preference and systemd disagree.
QQC.Popup {
    id: root
    required property var controller
    readonly property var decision: controller.drift
    // Popup items carry no screen; resolve tokens through the visual parent.
    readonly property Item tokens: parent
    signal dismissed
    modal: true
    focus: true
    closePolicy: QQC.Popup.NoAutoClose
    width: Math.min(400, parent.width)
    height: Math.min(parent.height, contentColumn.implicitHeight + padding * 2)
    x: (parent.width - width) / 2
    y: Math.max(0, (parent.height - height) / 2)
    padding: tokens.Tokens.padding.large
    onDecisionChanged: decision ? open() : close()
    onOpened: first.forceActiveFocus()
    background: StyledRect {
        color: Colours.palette.m3surfaceContainerHigh
        radius: root.tokens.Tokens.rounding.large
    }
    QQC.Overlay.modal: StyledRect {
        color: Qt.rgba(0, 0, 0, 0.45)
        radius: root.tokens.Tokens.rounding.large
    }
    contentItem: ColumnLayout {
        id: contentColumn
        spacing: root.tokens.Tokens.spacing.medium
        StyledText {
            Layout.fillWidth: true
            text: root.decision ? root.decision.message : ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        SharedWidgetBusyButton {
            id: first
            Layout.fillWidth: true
            caption: root.decision ? root.decision.first.label : ""
            primary: true
            busy: root.controller.busy
            onClicked: root.controller.chooseDrift(root.decision.first)
        }
        SharedWidgetBusyButton {
            id: second
            Layout.fillWidth: true
            caption: root.decision ? root.decision.second.label : ""
            disabled: root.controller.busy
            onClicked: root.controller.chooseDrift(root.decision.second)
        }
        StyledText {
            Layout.fillWidth: true
            text: root.controller.error
            textFormat: Text.PlainText
            visible: !!text
            wrapMode: Text.Wrap
            color: Colours.palette.m3error
        }
        Keys.onUpPressed: first.forceActiveFocus()
        Keys.onDownPressed: second.forceActiveFocus()
        Keys.onEscapePressed: root.dismissed()
    }
    Component.onCompleted: if (decision)
        open()
}
