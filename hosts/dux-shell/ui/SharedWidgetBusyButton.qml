import QtQuick
import qs.Common
import "UiConstants.js" as UiConstants

// Text action whose width covers both captions, so busy text never resizes it.
FocusScope {
    id: root
    property string text: ""
    property string busyText: "Working"
    property string iconName: ""
    property bool busy: false
    property string help: ""
    property bool primary: false
    property real controlHeight: UiConstants.CONTROL_HEIGHT
    signal clicked

    function activateKey(event) {
        if ([Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter].indexOf(event.key) < 0)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat && enabled && !busy)
            clicked();
    }
    Keys.onPressed: event => activateKey(event)
    implicitWidth: Math.max(button.implicitWidth, busyMetrics.advanceWidth + Theme.spacingM * 2 + Theme.fontSizeSmall + 4 + Theme.spacingXS)
    implicitHeight: controlHeight
    TextMetrics {
        id: busyMetrics
        text: root.busyText
        font.pixelSize: Theme.fontSizeSmall
    }
    SharedWidgetTooltipButton {
        id: button
        focus: true
        anchors.fill: parent
        controlHeight: root.controlHeight
        text: root.busy ? root.busyText : root.text
        iconName: root.busy && !root.iconName ? "sync" : root.iconName
        help: root.help
        primary: root.primary
        handlesKeys: false
        enabled: root.enabled && !root.busy
        onClicked: if (!root.busy)
            root.clicked()
    }
    // Omarchy keeps a busy button's icon moving: refresh spins, the others pulse.
    RotationAnimator {
        target: button.iconItem
        from: 0
        to: 360
        duration: 1000
        loops: Animation.Infinite
        running: root.busy && button.iconName !== "monitor_heart"
        onRunningChanged: if (!running)
            button.iconItem.rotation = 0
    }
    SequentialAnimation {
        running: root.busy && button.iconName === "monitor_heart"
        loops: Animation.Infinite
        onRunningChanged: if (!running)
            button.iconItem.opacity = 1
        OpacityAnimator {
            target: button.iconItem
            from: 1
            to: 0.35
            duration: 500
        }
        OpacityAnimator {
            target: button.iconItem
            from: 0.35
            to: 1
            duration: 500
        }
    }
}
