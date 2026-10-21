pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import "."

QQC.Popup {
    id: root
    required property var controller
    modal: true
    focus: true
    closePolicy: QQC.Popup.NoAutoClose
    width: Math.min(400, parent.width)
    height: Math.min(parent.height, contentColumn.implicitHeight + padding * 2)
    x: (parent.width - width) / 2
    y: Math.max(0, (parent.height - height) / 2)
    padding: Tokens.padding.large
    onOpened: cancel.forceActiveFocus()
    background: StyledRect {
        color: Colours.palette.m3surfaceContainerHigh
        radius: Tokens.rounding.medium
    }
    contentItem: ColumnLayout {
        id: contentColumn
        StyledText {
            Layout.fillWidth: true
            text: root.controller.view.confirmation?.title || ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        StyledFlickable {
            id: detailsScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: details.implicitHeight
            contentWidth: width
            contentHeight: details.implicitHeight
            clip: true
            interactive: contentHeight > height
            QQC.ScrollBar.vertical: StyledScrollBar {
                flickable: detailsScroll
            }
            ColumnLayout {
                id: details
                width: parent.width
                StyledText {
                    Layout.fillWidth: true
                    text: root.controller.view.confirmation?.detail || ""
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.controller.error
                    textFormat: Text.PlainText
                    visible: !!text
                    wrapMode: Text.Wrap
                    color: Colours.palette.m3error
                }
            }
        }
        RowLayout {
            BusyButton {
                id: cancel
                caption: "Cancel"
                disabled: root.controller.busy
                onClicked: root.controller.cancelConfirmation()
            }
            BusyButton {
                caption: "Confirm"
                busy: root.controller.busy
                onClicked: root.controller.acceptConfirmation()
            }
        }
        Keys.onEscapePressed: root.controller.cancelConfirmation()
    }
    Connections {
        target: root.controller
        function onViewChanged() {
            if (root.controller.view.confirmation)
                root.open();
            else
                root.close();
        }
    }
    Component.onCompleted: if (controller.view.confirmation)
        open()
}
