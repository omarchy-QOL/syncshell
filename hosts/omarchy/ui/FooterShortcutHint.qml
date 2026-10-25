import QtQuick
import qs.Commons

Text {
    id: root

    property var controller

    text: root.controller.settingsMenuOpen || root.controller.settingsMigrationOpen ? "" : "[r]escan  [w]ebUI  [p]ause/continue  [s]ettings"
    textFormat: Text.PlainText
    color: root.controller.dim
    font.family: root.controller.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 0.8
}
