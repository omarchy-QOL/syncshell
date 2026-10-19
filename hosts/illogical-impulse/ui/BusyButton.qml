import QtQuick

Item {
    id: root
    required property var style
    property string selectionState: ""
    property bool iconOnly: false
    property string actionIcon: "refresh"
    property string text: ""
    property string accessibleLabel: text
    property string help: ""
    property bool busy: false
    property string busyText: "Working…"
    property string tone: "foreground"
    property string disabledReason: ""
    readonly property bool navigationControl: true
    objectName: text.toLowerCase().replace(/[^a-z0-9]+/g, "-")
    Accessible.name: accessibleLabel
    Accessible.description: enabled ? help : disabledReason || help
    property bool selected: false
    signal clicked(var source)
    signal alternate
    readonly property alias item: content.item
    Loader {
        id: content
        anchors.fill: parent
        sourceComponent: root.iconOnly ? root.style.iconButton : root.style.button
    }
    implicitWidth: item ? item.implicitWidth : 0
    implicitHeight: item ? item.implicitHeight : 0
    function focusControl() {
        if (item)
            item.forceActiveFocus();
    }
    Binding {
        target: root.item
        property: "label"
        value: root.busy ? root.busyText : root.text
    }
    Binding {
        target: root.item
        property: "help"
        value: !root.enabled ? root.disabledReason || root.help : root.help
    }
    Binding {
        target: root.item
        property: "selected"
        value: root.selected
    }
    Binding {
        target: root.item
        property: "enabled"
        value: root.enabled && !root.busy
    }
    Binding {
        target: root.item
        property: "actionIcon"
        value: root.actionIcon
        when: root.iconOnly
    }
    Binding { target: root.item; property: "contentColor"; value: root.style.colorFor(root.tone) }
    Binding { target: root.item; property: "destructive"; value: root.tone === "danger" }
    Binding { target: root.item; property: "selectionState"; value: root.selectionState; when: !root.iconOnly }
    DisabledHelp {
        control: root
        style: root.style
        text: root.disabledReason || root.help
    }
    Binding { target: root.item; property: "accessibleLabel"; value: root.accessibleLabel }
    Connections {
        target: root.item
        function onActivated() {
            root.clicked(root);
        }
        function onAlternate() {
            root.alternate();
        }
    }
}
