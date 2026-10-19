import QtQuick.Layouts
import qs.modules.common
import QtQuick
import qs.modules.common.widgets

RippleButton {
    id: root
    implicitWidth: nativeContent.implicitWidth + leftPadding + rightPadding
    implicitHeight: nativeContent.implicitHeight + topPadding + bottomPadding
    property color contentColor: Appearance.colors.colOnLayer0
    property bool destructive: false
    property string selectionState: ""
    property string label: ""
    property string accessibleLabel: label
    property bool selected: false
    property string help: ""
    signal activated
    signal alternate
    buttonText: label
    toggled: selected
    focusPolicy: Qt.StrongFocus
    Accessible.name: root.accessibleLabel
    Accessible.description: root.help
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
        id: nativeContent
        spacing: 8
        NativeSelectionMark {
            selection: root.selectionState
            visible: root.selectionState !== ""
        }
        StyledText {
            Layout.fillWidth: true
            color: root.contentColor
            text: root.label
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
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
