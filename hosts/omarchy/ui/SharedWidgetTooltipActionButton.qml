import QtQuick
import qs.Ui as Ui

Ui.PanelActionButton {
    id: root

    property string helpText: ""

    tooltipText: ""

    HoverHandler {
        id: tooltipHover
    }

    SharedWidgetToolTip {
        visible: root.enabled && root.helpText !== "" && tooltipHover.hovered
        text: root.helpText
        fontFamily: root.fontFamily
    }
}
