pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import qs.components.controls
import qs.services

IconButton {
    id: root
    property string help: ""
    enabled: !disabled
    activeFocusOnTab: enabled
    border.width: activeFocus ? 2 : 0
    border.color: Colours.palette.m3primary
    QQC.ToolTip.visible: hovered || activeFocus
    QQC.ToolTip.text: help
    QQC.ToolTip.delay: 500
    Accessible.name: help
    Keys.onPressed: event => {
        if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)) {
            event.accepted = true;
            if (!event.isAutoRepeat && !disabled)
                clicked();
        }
    }
}
