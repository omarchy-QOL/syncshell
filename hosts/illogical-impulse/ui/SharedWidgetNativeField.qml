import QtQuick

Item {
    id: root
    required property var style
    property string text: ""
    property string placeholder: ""
    readonly property bool navigationControl: true
    property string accessibleLabel: placeholder
    Accessible.name: accessibleLabel
    property bool readOnly: false
    signal edited(string value)
    signal accepted
    readonly property alias item: content.item
    Loader {
        id: content
        anchors.fill: parent
        sourceComponent: style.field
    }
    implicitHeight: item ? item.implicitHeight : 0
    function focusControl() {
        if (item)
            item.forceActiveFocus();
    }
    Binding {
        target: root.item
        property: "text"
        value: root.text
    }
    Binding {
        target: root.item
        property: "placeholderText"
        value: root.placeholder
    }
    Binding {
        target: root.item
        property: "readOnly"
        value: root.readOnly
    }
    Connections {
        target: root.item
        function onTextEdited() {
            root.edited(root.item.text);
        }
        function onAccepted() {
            root.accepted();
        }
    }
}
