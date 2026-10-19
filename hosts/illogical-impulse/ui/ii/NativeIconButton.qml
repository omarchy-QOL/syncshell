import qs.modules.common
import QtQuick
import qs.modules.common.widgets

IconToolbarButton {
    id: root
    property color contentColor: Appearance.colors.colOnLayer0
    property bool destructive: false
    property string label: ""
    property string accessibleLabel: label
    property string actionIcon: "refresh"
    property bool selected: false
    property string help: ""
    signal activated
    signal alternate
    readonly property var icons: ({
            refresh: "refresh",
            settings: "settings",
            scan: "sync",
            add: "add",
            close: "close"
        })
    text: icons[actionIcon]
    colText: contentColor
    toggled: selected
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
        border.color: Appearance.colors.colPrimary
        radius: root.buttonRadius
    }
    NativeToolTip {
        text: root.help || root.label
        visible: root.hovered
    }
}
