import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Syncthing status mark: tinted mono asset when themed, full colour when branded.
Item {
    id: root
    property string variant: "default"
    property bool themed: true
    property color tint: Theme.onSurface
    property int size: 24
    implicitWidth: size
    implicitHeight: size
    DSVGIcon {
        anchors.centerIn: parent
        size: root.size
        source: Qt.resolvedUrl("../../../assets/" + (root.themed ? "mono/" : "") + "status-" + root.variant + ".svg")
        colorOverride: root.themed ? root.tint : "transparent"
    }
}
