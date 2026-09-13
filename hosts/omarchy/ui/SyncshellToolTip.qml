import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui
import "UiConstants.js" as UiConstants

Controls.ToolTip {
  id: root

  property color tooltipBackground: Color.tooltip.background
  property color tooltipForeground: Color.tooltip.text
  property color tooltipBorder: Color.tooltip.border
  property string fontFamily: Style.font.family

  readonly property var tooltipBorderSpec: Border.localOrSurfaceSpec(
    "tooltip", "border", tooltipBorder, Color.tooltip.border,
    Math.max(1, Style.normalBorderWidth))

  delay: UiConstants.TOOLTIP_DELAY_MS
  padding: 0

  background: BorderSurface {
    color: root.tooltipBackground
    borderSpec: root.tooltipBorderSpec
    radius: 0
  }

  contentItem: Text {
    textFormat: Text.PlainText
    text: root.text
    color: root.tooltipForeground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    leftPadding: Border.left(root.tooltipBorderSpec)
      + Style.spacing.controlPaddingX
    rightPadding: Border.right(root.tooltipBorderSpec)
      + Style.spacing.controlPaddingX
    topPadding: Border.top(root.tooltipBorderSpec)
      + Style.spacing.controlPaddingY
    bottomPadding: Border.bottom(root.tooltipBorderSpec)
      + Style.spacing.controlPaddingY
  }
}
