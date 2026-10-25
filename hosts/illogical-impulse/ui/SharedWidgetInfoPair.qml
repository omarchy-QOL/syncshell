import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    required property var style
    property string label: ""
    property string value: ""
    property string tone: "foreground"
    SharedWidgetNativeText {
        style: parent.style
        Layout.preferredWidth: 96
        Layout.alignment: Qt.AlignTop
        text: parent.label
        muted: true
    }
    SharedWidgetNativeText {
        style: parent.style
        text: parent.value
        tone: parent.tone
        Layout.fillWidth: true
    }
}
