import QtQuick
import qs.Ui as Ui

Ui.Button {
  id: root

  property string helpText: ""

  tooltipText: ""

  HoverHandler {
    id: tooltipHover
  }

  SyncshellToolTip {
    visible: root.helpText !== "" && tooltipHover.hovered
    text: root.helpText
    tooltipBackground: root.tooltipBackground
    tooltipForeground: root.tooltipForeground
    tooltipBorder: root.tooltipBorder
    fontFamily: root.fontFamily
  }
}
