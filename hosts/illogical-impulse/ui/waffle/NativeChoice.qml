import QtQuick
import QtQuick.Layouts
import qs.modules.waffle.looks

WChoiceButton {
    id: root
    implicitWidth: nativeContent.implicitWidth + root.leftPadding + root.rightPadding + root.leftInset + root.rightInset
    implicitHeight: nativeContent.implicitHeight + root.topPadding + root.bottomPadding + root.topInset + root.bottomInset
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
    text: label
    checked: selected
    focusPolicy: Qt.StrongFocus
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
        id: nativeContent
        spacing: 8
        NativeSelectionMark { selection: root.selected ? "checked" : "empty" }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            WText {
                Layout.fillWidth: true
                text: root.label
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                font.bold: root.current
            }
            WText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.detail
                textFormat: Text.PlainText
                elide: Text.ElideMiddle
                opacity: 0.7
            }
        }
        WText {
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
        border.color: Looks.colors.accent
        radius: root.radius
    }
    NativeToolTip {
        text: root.help
        visible: root.hovered && text !== ""
    }
}
