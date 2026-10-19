import QtQuick
import QtQuick.Controls
import qs.modules.waffle.looks

WToolbarTabBar {
    id: root
    property string selectedTab: "folders"
    signal chosen(string value)
    currentIndex: 0
    onSelectedTabChanged: currentIndex = selectedTab === "folders" ? 0 : 1
    onCurrentIndexChanged: if (currentIndex >= 0) chosen(currentIndex === 0 ? "folders" : "devices")
    Component.onCompleted: currentIndex = selectedTab === "folders" ? 0 : 1
    // The pin's toolbar consumes pointer presses; explicit hit regions keep
    // selection wired while its native indicator and keyboard tabs are retained.
    TabButton {
        objectName: "tab-folders"
        readonly property bool navigationControl: true
        function focusControl() { forceActiveFocus(); }
        text: "Folders"
        background: Item {}
        contentItem: WText {
            text: "Folders"
            horizontalAlignment: Text.AlignHCenter
        }
        onClicked: root.chosen("folders")
    }
    TabButton {
        objectName: "tab-devices"
        readonly property bool navigationControl: true
        function focusControl() { forceActiveFocus(); }
        text: "Devices"
        background: Item {}
        contentItem: WText {
            text: "Devices"
            horizontalAlignment: Text.AlignHCenter
        }
        onClicked: root.chosen("devices")
    }
    MouseArea {
        z: 10000
        anchors.fill: parent
        onClicked: event => root.currentIndex = event.x < width / 2 ? 0 : 1
    }
}
