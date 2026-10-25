import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import "UiConstants.js" as UiConstants

// Compact DMS-styled text button at Omarchy's control size. Tonal by default;
// `primary` marks the one emphasized action, `flat` drops the background.
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
    readonly property color foreground: !enabled ? Theme.surfaceVariantText : primary || checked ? Theme.primaryText : flat ? Theme.surfaceText : Theme.surfaceText
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
    opacity: enabled ? 1 : 0.5
    Keys.onPressed: event => {
        if (handlesKeys)
            activateKey(event);
    }
    Accessible.role: Accessible.Button
    Accessible.name: help || text
    StyledRect {
        id: surface
        anchors.fill: parent
        radius: Theme.cornerRadius / 2
        color: root.primary || root.checked ? Theme.primary : root.flat ? "transparent" : Theme.surfaceContainerHigh
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.primary
        RowLayout {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            x: root.leftAlign ? Theme.spacingM : (parent.width - width) / 2
            spacing: Theme.spacingXS
            DankIcon {
                visible: root.iconName !== ""
                name: root.iconName
                size: root.fontSize + 4
                color: root.foreground
            }
            StyledText {
                visible: root.text !== ""
                text: root.text
                textFormat: Text.PlainText
                font.pixelSize: root.fontSize
                color: root.foreground
            }
        }
        StateLayer {
            anchors.fill: parent
            disabled: !root.enabled
            stateColor: root.foreground
            tooltipText: root.help || null
            onClicked: root.clicked()
        }
    }
}
