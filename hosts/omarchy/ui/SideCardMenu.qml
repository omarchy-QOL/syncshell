import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

Popup {
    id: root

    required property Item panel
    required property Item trigger
    property bool shown: false

    parent: trigger
    x: {
        positionWatcher.transform;
        return panel.mapToItem(trigger, 0, 0).x - width;
    }
    y: 0
    width: panel.width
    margins: Style.space(8)
    padding: Style.space(8)
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    // Closing resets the form state after its visibility binding settles.
    Binding {
        target: root
        property: "visible"
        value: root.shown && root.panel.visible
        delayed: true
    }

    TransformWatcher {
        id: positionWatcher
        a: root.panel
        b: root.trigger
    }

    background: BorderSurface {
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
        color: Color.popups.background
        radius: Style.cornerRadius
    }
}
