import QtQuick
import qs.Common
import qs.Widgets
import "UiConstants.js" as UiConstants

// Square icon-only button with a DMS tooltip; size follows Omarchy's controls.
FocusScope {
    id: root
    property string iconName: ""
    property string help: ""
    property bool danger: false
    property real size: UiConstants.CONTROL_HEIGHT
    property bool handlesKeys: true
    signal clicked

    activeFocusOnTab: enabled
    implicitWidth: size
    implicitHeight: size
    opacity: enabled ? 1 : 0.5
    Accessible.role: Accessible.Button
    Accessible.name: help
    Keys.onPressed: event => {
        if (!handlesKeys)
            return;
        if ([Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter].indexOf(event.key) < 0)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat && enabled)
            clicked();
    }
    StyledRect {
        anchors.fill: parent
        radius: Theme.cornerRadius / 2
        color: Theme.surfaceContainerHigh
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.primary
        DankIcon {
            anchors.centerIn: parent
            name: root.iconName
            size: Math.round(root.size * 0.6)
            color: !root.enabled ? Theme.surfaceVariantText : root.danger ? Theme.error : Theme.surfaceText
        }
        StateLayer {
            anchors.fill: parent
            disabled: !root.enabled
            tooltipText: root.help || null
            onClicked: root.clicked()
        }
    }
}
