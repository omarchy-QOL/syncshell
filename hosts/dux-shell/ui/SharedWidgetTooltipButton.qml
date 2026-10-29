import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "UiConstants.js" as UiConstants

// Compact text button at Omarchy's control size. DButton fixes a 14 px label
// and a 32 px minimum, so this keeps DButton's tokens on a smaller control.
// Tonal by default; `primary` marks the emphasized action, `flat` drops the fill.
FocusScope {
    id: root
    property string text: ""
    property string iconName: ""
    property string help: ""
    property bool primary: false
    property bool flat: false
    property bool checked: false
    property bool leftAlign: false
    property real controlHeight: UiConstants.CONTROL_HEIGHT
    property real fontSize: Theme.fontSizeSmall
    // Omarchy's placeholders look disabled but keep their tooltip.
    property bool canActivate: true
    // Wrappers with their own busy rules handle keys themselves.
    property bool handlesKeys: true
    readonly property color foreground: !enabled || !canActivate ? Theme.onSurface_38 : primary || checked ? Theme.onPrimary : Theme.onSurface
    signal clicked

    function activateKey(event) {
        if ([Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter].indexOf(event.key) < 0)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat && enabled && canActivate)
            clicked();
    }
    activeFocusOnTab: enabled && canActivate
    readonly property real iconRoom: iconName !== "" ? fontSize + 4 + (text !== "" ? Theme.spacingXS : 0) : 0
    implicitWidth: iconRoom + (text !== "" ? label.implicitWidth : 0) + Theme.spacingM * 2
    implicitHeight: controlHeight
    Keys.onPressed: event => {
        if (handlesKeys)
            activateKey(event);
    }
    Accessible.role: Accessible.Button
    Accessible.name: help || text
    StyledRect {
        id: surface
        anchors.fill: parent
        radius: Theme.buttonRadius(width, height, root.controlHeight, stateLayer.pressed, !root.flat)
        color: (!root.enabled || !root.canActivate) && !root.flat ? Theme.onSurface_12 : root.primary || root.checked ? Theme.primary : root.flat ? "transparent" : Theme.chipSurface
        FocusRing {
            visible: root.activeFocus
        }
        Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            x: root.leftAlign ? Theme.spacingM : (parent.width - width) / 2
            spacing: root.iconName !== "" && root.text !== "" ? Theme.spacingXS : 0
            DIcon {
                id: icon
                anchors.verticalCenter: parent.verticalCenter
                visible: root.iconName !== ""
                name: root.iconName
                size: root.fontSize + 4
                color: root.foreground
            }
            // Width from the text and the room left, not from a layout's
            // cached hint, so swapped busy captions never stay cut.
            StyledText {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                visible: root.text !== ""
                width: Math.min(implicitWidth, Math.max(0, surface.width - Theme.spacingM * 2 - root.iconRoom))
                // StyledText wraps by default; a label must elide on one line.
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                text: root.text
                textFormat: Text.PlainText
                font.pixelSize: root.fontSize
                color: root.foreground
            }
        }
        StateLayer {
            id: stateLayer
            anchors.fill: parent
            disabled: !root.enabled
            stateColor: root.canActivate ? root.foreground : "transparent"
            cursorShape: root.canActivate ? Qt.PointingHandCursor : Qt.ArrowCursor
            tooltipText: root.help || null
            // Single-line tooltips drop everything after a line break.
            tooltipMultiline: root.help.indexOf("\n") >= 0
            onClicked: if (root.canActivate)
                root.clicked()
        }
    }
}
