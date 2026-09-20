import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

RowLayout {
  id: root

  property string title: ""
  property string cancelText: "CANCEL"
  property color foreground: Color.foreground
  property color cancelColor: Color.urgent
  property string fontFamily: Style.font.family
  property bool cancelEnabled: true

  signal canceled()

  width: parent ? parent.width : implicitWidth

  PanelSectionHeader {
    Layout.fillWidth: true
    text: root.title
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Button {
    text: root.cancelText
    bordered: true
    foreground: root.cancelColor
    fontFamily: root.fontFamily
    fontSize: Style.font.caption
    horizontalPadding: Style.space(6)
    verticalPadding: Style.space(4)
    enabled: root.cancelEnabled
    onClicked: root.canceled()
  }
}
