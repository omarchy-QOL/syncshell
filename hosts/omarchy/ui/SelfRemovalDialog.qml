import QtQuick
import qs.Commons
import qs.Ui

FocusScope {
    id: root

    property bool opened: false
    property bool busy: false
    property string error: ""
    property int selectedChoice: 2
    property string fontFamily: Style.font.family
    readonly property var cardBorderSpec: Border.surfaceSpec(
        "menu", "border", Color.menu.border, Math.max(1, Style.space(1)))
    readonly property var selectedBorderSpec: Border.surfaceSpec(
        "menu", "selected-border", Color.menu.selectedBorder, 0)

    signal removeRequested(bool deletePluginSettings)
    signal canceled

    function choose() {
        if (busy)
            return;
        if (selectedChoice === 0)
            removeRequested(false);
        else if (selectedChoice === 1)
            removeRequested(true);
        else
            canceled();
    }

    visible: opened
    onOpenedChanged: if (opened)
        selectedChoice = 2

    Rectangle {
        anchors.fill: parent
        color: Color.menu.scrim

        BorderSurface {
            width: Math.min(parent.width - Style.spacing.panelPadding * 2, Style.space(480))
            height: confirmationColumn.implicitHeight + Style.spacing.panelPadding * 2
            anchors.centerIn: parent
            radius: Style.cornerRadius
            color: Color.menu.background
            borderSpec: root.cardBorderSpec

            Column {
                id: confirmationColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.spacing.panelPadding
                spacing: Style.space(3)

                Text {
                    width: parent.width
                    bottomPadding: Style.spacing.sm
                    text: "Remove Syncthing plugin ?"
                    textFormat: Text.PlainText
                    color: Color.menu.text
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.heading
                    font.bold: true
                }

                Text {
                    width: parent.width
                    visible: root.error !== ""
                    text: root.error
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Color.urgent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                }

                Repeater {
                    model: ["Yes (preserve plugin settings)", "Yes (delete plugin settings)", "No / abort"]

                    delegate: BorderSurface {
                        id: choiceRow
                        required property int index
                        required property string modelData

                        width: confirmationColumn.width
                        height: Style.space(40)
                        radius: Style.cornerRadius
                        color: root.selectedChoice === index ? Color.menu.selectedBackground : "transparent"
                        borderSpec: root.selectedChoice === index
                            ? root.selectedBorderSpec : Border.none()

                        Rectangle {
                            visible: choiceRow.index === 2
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: Math.max(1, Style.space(1))
                            color: Util.alpha(Color.menu.text, 0.18)
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Style.spacing.md
                            anchors.verticalCenter: parent.verticalCenter
                            text: choiceRow.modelData
                            textFormat: Text.PlainText
                            color: root.selectedChoice === choiceRow.index ? Color.menu.selectedText : (choiceRow.index === 1 ? Color.urgent : Color.menu.text)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.title
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.busy
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selectedChoice = choiceRow.index
                            onClicked: root.choose()
                        }
                    }
                }
            }
        }
    }
}
