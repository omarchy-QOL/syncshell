import QtQuick
import qs.Commons
import qs.Ui

Item {
    id: root

    property int selectedIndex: 0
    property string fontFamily: Style.font.family
    readonly property color foreground: Color.popups.text
    readonly property color selectedBackground: Style.selectedFillFor(
        foreground, Color.accent, Color.urgent)
    readonly property color selectedText: Style.selectedStateColor(
        foreground, Color.accent, Color.urgent)
    signal highlightRequested(int index)
    signal activated(int index)

    readonly property var rows: [
        {
            title: "Open settings file",
            description: "Edit icon and Web UI preferences",
            separatorBefore: false,
            dangerous: false
        },
        {
            title: "Cleanly remove Syncthing plugin",
            description: "Optionally delete plugin settings",
            separatorBefore: false,
            dangerous: true
        },
        {
            title: "Back [q / Esc]",
            description: "Return to Syncthing",
            separatorBefore: true,
            dangerous: false
        }
    ]

    implicitHeight: menuColumn.implicitHeight

    Column {
        id: menuColumn
        width: parent.width
        spacing: Style.space(3)

        PanelSectionHeader {
            width: parent.width
            bottomPadding: Style.spacing.sm
            text: "SETTINGS"
            foreground: root.foreground
            fontFamily: root.fontFamily
        }

        Repeater {
            model: root.rows

            delegate: Rectangle {
                id: menuRow
                required property int index
                required property var modelData

                width: menuColumn.width
                height: Style.space(60)
                radius: Style.cornerRadius
                color: root.selectedIndex === index
                    ? root.selectedBackground : "transparent"

                Rectangle {
                    visible: menuRow.modelData.separatorBefore
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: Math.max(1, Style.space(1))
                    color: Util.alpha(root.foreground, 0.18)
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Style.spacing.md
                    anchors.rightMargin: Style.spacing.md
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(2)

                    Text {
                        width: parent.width
                        text: menuRow.modelData.title
                        textFormat: Text.PlainText
                        color: root.selectedIndex === menuRow.index
                            ? root.selectedText
                            : (menuRow.modelData.dangerous
                                ? Color.urgent : root.foreground)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.title
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: menuRow.modelData.description
                        textFormat: Text.PlainText
                        color: root.selectedIndex === menuRow.index
                            ? root.selectedText : root.foreground
                        opacity: 0.65
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.highlightRequested(menuRow.index)
                    onClicked: root.activated(menuRow.index)
                }
            }
        }
    }
}
