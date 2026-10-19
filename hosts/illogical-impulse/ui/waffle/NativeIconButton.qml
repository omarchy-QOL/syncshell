import QtQuick
import qs.modules.waffle.looks

WToolbarIconButton {
    id: root
    property color contentColor: Looks.colors.fg
    property bool destructive: false
    property string label: ""
    property string accessibleLabel: label
    property string actionIcon: "refresh"
    property bool selected: false
    property string help: ""
    signal activated
    signal alternate
    readonly property var icons: ({
            refresh: "arrow-counterclockwise",
            settings: "settings",
            scan: "arrow-sync",
            add: "add",
            close: "dismiss"
        })
    icon.name: icons[actionIcon]
    colForeground: contentColor
    checked: selected
    focusPolicy: Qt.StrongFocus
    Accessible.name: root.accessibleLabel
    Accessible.description: root.help
    onClicked: activated()
    altAction: () => root.alternate()
    Keys.onPressed: event => {
        if (event.isAutoRepeat)
            event.accepted = true;
    }
    Keys.onReleased: event => {
        if (event.isAutoRepeat)
            event.accepted = true;
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: Looks.colors.accent
        radius: root.radius
    }
    NativeToolTip {
        text: root.help || root.label
        visible: root.hovered
    }
}
