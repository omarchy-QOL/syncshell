import QtQuick
import qs.modules.waffle.looks

WToolTip {
    id: root
    realContentItem: WText {
        text: root.text
        textFormat: Text.PlainText
        font: root.font
        anchors.centerIn: parent
    }
}
