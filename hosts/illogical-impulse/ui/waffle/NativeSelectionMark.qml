import QtQuick
import qs.modules.waffle.looks

Rectangle {
    id: root
    property string selection: "empty"
    implicitWidth: 18
    implicitHeight: 18
    radius: 3
    color: selection === "empty" ? "transparent" : Looks.colors.accent
    border.width: 1
    border.color: selection === "empty" ? Looks.colors.subfg : Looks.colors.accent
    FluentIcon {
        anchors.centerIn: parent
        implicitSize: 14
        icon: root.selection === "mixed" ? "subtract" : "checkmark"
        color: Looks.colors.accentFg
        visible: root.selection !== "empty"
    }
}
