import QtQuick
import qs.modules.common.widgets

SecondaryTabBar {
    id: root
    property string selectedTab: "folders"
    signal chosen(string value)
    currentIndex: 0
    onSelectedTabChanged: currentIndex = selectedTab === "folders" ? 0 : 1
    onCurrentIndexChanged: if (currentIndex >= 0) chosen(currentIndex === 0 ? "folders" : "devices")
    Component.onCompleted: currentIndex = selectedTab === "folders" ? 0 : 1
    SecondaryTabButton {
        objectName: "tab-folders"
        readonly property bool navigationControl: true
        function focusControl() { forceActiveFocus(); }
        buttonText: "Folders"
        onClicked: chosen("folders")
    }
    SecondaryTabButton {
        objectName: "tab-devices"
        readonly property bool navigationControl: true
        function focusControl() { forceActiveFocus(); }
        buttonText: "Devices"
        onClicked: chosen("devices")
    }
}
