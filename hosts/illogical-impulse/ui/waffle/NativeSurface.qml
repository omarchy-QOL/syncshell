import QtQuick
import qs.modules.waffle.looks

WPane {
    id: root
    property real footerHeight: 0
    implicitWidth: 0
    implicitHeight: 0
    contentItem: Item {
        implicitWidth: Math.max(0, root.width - 2)
        implicitHeight: Math.max(0, root.height - 2)
        BodyRectangle {
            anchors.fill: parent
            anchors.bottomMargin: root.footerHeight
        }
        FooterRectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: root.footerHeight
            visible: height > 0
        }
    }
}
