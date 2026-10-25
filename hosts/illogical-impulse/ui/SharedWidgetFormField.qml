import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var style
    property string label: ""
    property alias text: input.text
    property alias placeholder: input.placeholder
    property alias readOnly: input.readOnly
    readonly property alias item: input.item
    property string help: ""
    signal edited(string value)
    signal accepted
    spacing: style.spacing / 2
    function focusControl() { input.focusControl(); }
    SharedWidgetNativeText { style: root.style; text: root.label; Layout.fillWidth: true }
    SharedWidgetNativeField {
        id: input
        objectName: root.objectName + "-input"
        style: root.style
        accessibleLabel: root.label
        Layout.fillWidth: true
        onEdited: value => root.edited(value)
        onAccepted: root.accepted()
    }
    SharedWidgetNativeText { style: root.style; text: root.help; visible: text !== ""; muted: true; Layout.fillWidth: true }
}
