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
    // Popup items carry no screen; resolve tokens through the visual parent.
    readonly property Item tokens: parent
    modal: true
    focus: true
    closePolicy: QQC.Popup.NoAutoClose
    width: Math.min(400, parent.width)
    height: Math.min(parent.height, contentColumn.implicitHeight + padding * 2)
    x: (parent.width - width) / 2
    y: Math.max(0, (parent.height - height) / 2)
    padding: tokens.Tokens.padding.large
    // Return focus to the control that asked for confirmation, not the tabs.
    property Item returnFocus: null
    onAboutToShow: returnFocus = parent?.Window.window?.activeFocusItem ?? null
    onOpened: cancel.forceActiveFocus()
    onClosed: {
        const target = returnFocus;
        returnFocus = null;
        if (target)
            Qt.callLater(() => {
                if (target.visible && target.enabled)
                    target.forceActiveFocus();
            });
    }
    background: StyledRect {
        color: Colours.palette.m3surfaceContainerHigh
        radius: root.tokens.Tokens.rounding.large
    }
    // Dim the panel behind, as Omarchy's and DMS's confirmations do.
    QQC.Overlay.modal: StyledRect {
        color: Qt.rgba(0, 0, 0, 0.45)
        radius: root.tokens.Tokens.rounding.large
    }
    contentItem: ColumnLayout {
        id: contentColumn
        spacing: root.tokens.Tokens.spacing.medium
        StyledText {
            Layout.fillWidth: true
            text: root.controller.view.confirmation?.title || ""
            textFormat: Text.PlainText
            font: root.tokens.Tokens.font.title.small
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
                    color: Colours.palette.m3onSurfaceVariant
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
        // Omarchy's order: confirm first, focus on the cancel choice.
        RowLayout {
            SharedWidgetBusyButton {
                readonly property bool destructive: root.controller.view.confirmation?.destructive !== false
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                caption: root.controller.view.confirmation?.confirm || "Yes"
                primary: true
                busy: root.controller.busy
                inactiveColour: destructive ? Colours.palette.m3error : Colours.palette.m3primary
                inactiveOnColour: destructive ? Colours.palette.m3onError : Colours.palette.m3onPrimary
                onClicked: root.controller.acceptConfirmation()
            }
            SharedWidgetBusyButton {
                id: cancel
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                caption: root.controller.view.confirmation?.cancel || "No"
                disabled: root.controller.busy
                onClicked: root.controller.cancelConfirmation()
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
