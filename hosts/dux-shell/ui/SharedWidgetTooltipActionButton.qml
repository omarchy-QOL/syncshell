import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "UiConstants.js" as UiConstants

// Icon-only button at Omarchy's control size; DIconButton starts at 40 px.
FocusScope {
    id: root
    property string iconName: ""
    property string help: ""
    property bool danger: false
    // Accept actions, green like Omarchy's.
    property bool success: false
    property real size: UiConstants.CONTROL_HEIGHT
    property bool handlesKeys: true
    signal clicked

    activeFocusOnTab: enabled
    implicitWidth: size
    implicitHeight: size
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
        radius: stateLayer.pressed ? Theme.buttonRadius(width, height, root.size, true, false) : Theme.fullRadius(width, height)
        color: root.enabled ? Theme.chipSurface : Theme.onSurface_12
        FocusRing {
            visible: root.activeFocus
        }
        DIcon {
            anchors.centerIn: parent
            name: root.iconName
            size: Math.round(root.size * 0.6)
            color: !root.enabled ? Theme.onSurface_38 : root.danger ? Theme.error : root.success ? Theme.success : Theme.onSurfaceVariant
        }
        StateLayer {
            id: stateLayer
            anchors.fill: parent
            disabled: !root.enabled
            tooltipText: root.help || null
            onClicked: root.clicked()
        }
    }
}
