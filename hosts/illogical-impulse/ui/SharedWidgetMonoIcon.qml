import QtQuick
import QtQuick.Effects

Item {
    id: root
    required property var style
    property url source
    property bool monochrome: true
    implicitWidth: 24
    implicitHeight: 24
    Image {
        id: artwork
        anchors.fill: parent
        source: root.source
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        visible: !root.monochrome
    }
    MultiEffect {
        anchors.fill: artwork
        source: artwork
        visible: root.monochrome
        colorization: 1
        colorizationColor: root.style.foreground
    }
}
