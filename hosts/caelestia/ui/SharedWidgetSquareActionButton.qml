pragma ComponentBehavior: Bound

import QtQuick
import qs.components.controls
import qs.services
import "."

IconButton {
    id: root
    property string help: ""
    // Omarchy tints removal red and linking or accepting green.
    property bool danger: false
    property bool success: false
    type: IconButton.Tonal
    inactiveColour: danger ? Colours.palette.m3errorContainer : success ? Colours.palette.m3successContainer : Colours.palette.m3secondaryContainer
    inactiveOnColour: danger ? Colours.palette.m3onErrorContainer : success ? Colours.palette.m3onSuccessContainer : Colours.palette.m3onSecondaryContainer
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
