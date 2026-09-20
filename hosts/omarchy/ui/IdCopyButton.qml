import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Item {
  id: root

  property string value: ""
  property string notice: "ID copied"
  property string text: ""
  property string helpText: "Copy ID"
  property string variant: "button"
  property real size: Style.space(28)
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property int fontSize: Style.font.caption
  property int iconSize: Style.font.caption
  property int horizontalPadding: Style.space(4)
  property int verticalPadding: 0
  property var controller

  function copy() {
    if (!value) return
    Quickshell.execDetached(["wl-copy", "--", value])
    if (controller) controller.showNotice(notice)
  }

  implicitWidth: buttonLoader.item ? buttonLoader.item.implicitWidth : size
  implicitHeight: buttonLoader.item ? buttonLoader.item.implicitHeight : size

  Loader {
    id: buttonLoader
    anchors.fill: parent
    sourceComponent: root.variant === "panel" ? panelButton : regularButton
  }

  Component {
    id: panelButton

    TooltipPanelActionButton {
      size: root.size
      iconText: "󰆏"
      helpText: root.helpText
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      fontSize: root.fontSize
      onClicked: root.copy()
    }
  }

  Component {
    id: regularButton

    TooltipButton {
      text: root.text
      iconText: "󰆏"
      helpText: root.helpText
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      fontSize: root.fontSize
      iconSize: root.iconSize
      horizontalPadding: root.horizontalPadding
      verticalPadding: root.verticalPadding
      onClicked: root.copy()
    }
  }
}
