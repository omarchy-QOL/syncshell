import QtQuick.Layouts
import QtQuick
import qs.modules.waffle.looks

WButton {
    id: root
    implicitWidth: nativeContent.implicitWidth + root.leftPadding + root.rightPadding + root.leftInset + root.rightInset
    implicitHeight: nativeContent.implicitHeight + root.topPadding + root.bottomPadding + root.topInset + root.bottomInset
    property color contentColor: Looks.colors.fg
    property bool destructive: false
    property string selectionState: ""
    property string label: ""
    property string accessibleLabel: label
    property bool selected: false
    property string help: ""
    signal activated
    signal alternate
    text: label
    checked: selected
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
    contentItem: RowLayout {
        id: nativeContent
        spacing: 8
        NativeSelectionMark {
            selection: root.selectionState
            visible: root.selectionState !== ""
        }
        WText {
            Layout.fillWidth: true
            color: root.contentColor
            text: root.label
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font: root.font
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
