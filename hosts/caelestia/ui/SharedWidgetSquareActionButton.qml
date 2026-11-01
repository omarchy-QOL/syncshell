pragma ComponentBehavior: Bound

import QtQuick
import qs.components.controls
import qs.services
import "."

IconButton {
    id: root
    property string help: ""
    enabled: !disabled
    activeFocusOnTab: enabled
    border.width: activeFocus ? 2 : 0
    border.color: Colours.palette.m3primary
    SharedWidgetToolTip {
        visible: (root.hovered || root.activeFocus) && !!root.help
        text: root.help
    }
    Accessible.name: help
    Keys.onPressed: event => {
        if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)) {
            event.accepted = true;
            if (!event.isAutoRepeat && !disabled)
                clicked();
        }
    }
}
