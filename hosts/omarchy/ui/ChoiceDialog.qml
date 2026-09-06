import QtQuick
import qs.Commons

FocusScope {
  id: root

  property bool opened: false
  property bool busy: false
  property int selectedChoice: 0
  property string message: ""
  property var choices: []
  property var choiceEnabled: []
  property int initialChoice: 0
  property string busyText: "Applying Syncthing setting..."
  property string fontFamily: Style.font.family

  signal actionRequested(int index)

  function choose() {
    if (!busy && isEnabled(selectedChoice)) actionRequested(selectedChoice)
  }

  function isEnabled(index) {
    return !choiceEnabled.length || choiceEnabled[index] === true
  }

  function moveChoice(direction) {
    if (busy) return
    for (var step = 1; step <= choices.length; step++) {
      var index = (selectedChoice + (direction > 0 ? step : -step)
        + choices.length) % choices.length
      if (isEnabled(index)) { selectedChoice = index; return }
    }
  }

  visible: opened
  onOpenedChanged: if (opened) selectedChoice = initialChoice

  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Color.menu.background, 0.88)

    MouseArea {
      anchors.fill: parent
    }

    Rectangle {
      width: Math.min(parent.width - Style.spacing.panelPadding * 2,
        Style.space(480))
      height: content.implicitHeight + Style.spacing.panelPadding * 2
      anchors.centerIn: parent
      radius: Style.cornerRadius
      color: Color.menu.background
      border.width: Math.max(1, Style.space(1))
      border.color: Util.alpha(Color.menu.text, 0.18)

      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.spacing.panelPadding
        spacing: Style.space(6)

        Text {
          width: parent.width
          bottomPadding: Style.spacing.sm
          text: root.message
          textFormat: Text.PlainText
          color: Color.menu.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.Wrap
        }

        Repeater {
          model: root.choices

          delegate: Rectangle {
            id: choiceRow
            required property int index
            required property string modelData
            opacity: root.isEnabled(index) ? 1 : 0.45

            width: content.width
            height: Math.max(Style.space(40), choiceText.implicitHeight
              + Style.spacing.md * 2)
            radius: Style.cornerRadius
            color: root.selectedChoice === index
              ? Color.menu.selectedBackground : "transparent"
            border.width: Math.max(1, Style.space(1))
            border.color: root.selectedChoice === index
              ? Color.menu.selectedText : Util.alpha(Color.menu.text, 0.18)

            Text {
              id: choiceText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.spacing.md
              text: choiceRow.modelData
              textFormat: Text.PlainText
              color: root.selectedChoice === choiceRow.index
                ? Color.menu.selectedText : Color.menu.text
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
            }

            MouseArea {
              anchors.fill: parent
              enabled: !root.busy && root.isEnabled(choiceRow.index)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.selectedChoice = index
              onClicked: root.actionRequested(index)
            }
          }
        }

        Text {
          visible: root.busy
          width: parent.width
          topPadding: Style.spacing.sm
          text: root.busyText
          textFormat: Text.PlainText
          color: Util.alpha(Color.menu.text, 0.66)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignRight
        }
      }
    }
  }
}
