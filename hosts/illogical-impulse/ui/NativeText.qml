import QtQuick

Item {
    id: root
    required property var style
    property string text: ""
    property bool muted: false
    property string tone: "foreground"
    Accessible.name: text
    readonly property alias item: content.item
    Loader {
        id: content
        anchors.fill: parent
        sourceComponent: style.text
    }
    implicitWidth: item ? item.implicitWidth : 0
    implicitHeight: item ? item.implicitHeight : 0
    Binding {
        target: root.item
        property: "text"
        value: root.text
    }
    Binding {
        target: root.item
        property: "color"
        value: root.style.colorFor(root.muted ? "muted" : root.tone)
    }
}
