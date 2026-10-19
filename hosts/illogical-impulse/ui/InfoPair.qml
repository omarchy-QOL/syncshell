import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    required property var style
    property string label: ""
    property string value: ""
    property string tone: "foreground"
    NativeText {
        style: parent.style
        Layout.preferredWidth: 96
        Layout.alignment: Qt.AlignTop
        text: parent.label
        muted: true
    }
    NativeText {
        style: parent.style
        text: parent.value
        tone: parent.tone
        Layout.fillWidth: true
    }
}
