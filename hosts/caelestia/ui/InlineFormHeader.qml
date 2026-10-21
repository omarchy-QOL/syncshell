pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import "."

RowLayout {
    id: root
    property string title: ""
    property bool busy: false
    signal cancelled
    StyledText {
        Layout.fillWidth: true
        text: root.title
        textFormat: Text.PlainText
        font: Tokens.font.title.medium
        wrapMode: Text.Wrap
    }
    BusyButton {
        caption: "Cancel"
        disabled: root.busy
        onClicked: root.cancelled()
    }
}
