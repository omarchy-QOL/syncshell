import QtQuick
import qs.Commons
import qs.Ui

BusyButton {
    id: root

    property string glyph: ""
    property string helpText: ""

    implicitWidth: Style.spacing.controlHeight
    implicitHeight: Style.spacing.controlHeight
    iconText: busy ? "\uf110" : ""
    tooltipText: helpText
    bordered: true

    OpticalGlyph {
        id: opticalGlyph
        z: 1
        anchors.fill: parent
        visible: !root.busy
        text: root.glyph
        color: root.interactive ? root.foreground : root.disabledForeground
        fontFamily: root.fontFamily
        fontSize: root.iconSize
        transform: Translate {
            x: opticalGlyph.text === "\uf067" || opticalGlyph.text === "\uf00d" ? 1 : 0
            y: 1
        }
    }
}
