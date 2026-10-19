import qs.modules.common
import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets

RippleButton {
    id: root
    property string label: ""
    property string detail: ""
    property bool selected: false
    property string help: ""
    property string statusText: ""
    property color statusColor: "transparent"
    property bool current: false
    Accessible.name: label
    Accessible.description: detail + " " + statusText
    Accessible.selected: selected
    signal activated
    signal alternate
    buttonText: label
    toggled: selected
    focusPolicy: Qt.StrongFocus
    horizontalPadding: 12
    verticalPadding: 8
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
    contentItem: RowLayout {
        spacing: 8
        NativeSelectionMark { selection: root.selected ? "checked" : "empty" }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            StyledText {
                Layout.fillWidth: true
                text: root.label
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                font.bold: root.current
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.detail
                textFormat: Text.PlainText
                elide: Text.ElideMiddle
                opacity: 0.7
            }
        }
        StyledText {
            text: root.statusText
            color: root.statusColor
            visible: text !== ""
            textFormat: Text.PlainText
            Layout.maximumWidth: 90
            wrapMode: Text.Wrap
        }
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
        text: root.help
        visible: root.hovered && text !== ""
    }
}
