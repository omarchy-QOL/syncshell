import QtQuick
import QtQuick.Layouts
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
    // Wrappers with their own busy rules handle keys themselves.
    property bool handlesKeys: true
    readonly property color foreground: !enabled ? Theme.onSurface_38 : primary || checked ? Theme.onPrimary : Theme.onSurface
    signal clicked

    function activateKey(event) {
        if ([Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter].indexOf(event.key) < 0)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat && enabled)
            clicked();
    }
    activeFocusOnTab: enabled
    implicitWidth: row.implicitWidth + Theme.spacingM * 2
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
        color: !root.enabled && !root.flat ? Theme.onSurface_12 : root.primary || root.checked ? Theme.primary : root.flat ? "transparent" : Theme.chipSurface
        FocusRing {
            visible: root.activeFocus
        }
        RowLayout {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - (root.text !== "" ? Theme.spacingM * 2 : 0))
            x: root.leftAlign ? Theme.spacingM : (parent.width - width) / 2
            spacing: Theme.spacingXS
            DIcon {
                visible: root.iconName !== ""
                name: root.iconName
                size: root.fontSize + 4
                color: root.foreground
            }
            StyledText {
                visible: root.text !== ""
                Layout.fillWidth: true
                maximumLineCount: 1
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
            stateColor: root.foreground
            tooltipText: root.help || null
            onClicked: root.clicked()
        }
    }
}
