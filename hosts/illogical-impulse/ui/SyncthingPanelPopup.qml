import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var host
    readonly property var style: host.style
    readonly property var controller: host.controller
    readonly property var service: host.service
    spacing: style.spacing
    PanelStatus {
        style: root.style
        controller: root.controller
        Layout.fillWidth: true
    }
    Loader {
        id: tabs
        Layout.fillWidth: true
        sourceComponent: root.style.tabs
        Binding {
            target: tabs.item
            property: "selectedTab"
            value: root.controller.tab
        }
        Connections {
            target: tabs.item
            function onChosen(value) {
                root.controller.tab = value;
            }
        }
    }
    FolderOverview {
        style: root.style
        controller: root.controller
        Layout.fillWidth: true
        visible: root.controller.tab === "folders"
    }
    RemoteDevices {
        style: root.style
        controller: root.controller
        Layout.fillWidth: true
        visible: root.controller.tab === "devices"
    }
    PendingInvitations {
        style: root.style
        controller: root.controller
        Layout.fillWidth: true
    }
    BusyButton {
        style: root.style
        text: root.controller.more ? "Less" : "More"
        onClicked: root.controller.more = !root.controller.more
    }
    MoreDetails {
        style: root.style
        controller: root.controller
        Layout.fillWidth: true
        visible: root.controller.more
    }
    NativeText {
        style: root.style
        Layout.fillWidth: true
        objectName: "connection-error"
        tone: "danger"
        text: root.service.lastError
        visible: text !== ""
    }
    NativeText {
        style: root.style
        Layout.fillWidth: true
        text: root.service.actionNotice
        visible: text !== ""
    }
    BusyButton {
        style: root.style
        text: root.controller.confirmation ? "Resume confirmation" : "Resume draft"
        visible: root.controller.confirmation !== null || root.controller.view !== "" && !root.controller.formVisible
        onClicked: root.controller.reopen()
    }
}
