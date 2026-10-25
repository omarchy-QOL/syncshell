import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var host
    readonly property var style: host.style
    readonly property var controller: host.controller
    Loader {
        Layout.fillWidth: true
        active: root.host.service.busy || root.host.service.refreshing
        visible: active
        sourceComponent: root.style.busyIndicator
    }
    Flow {
        Layout.fillWidth: true
        spacing: root.style.spacing
        SharedWidgetBusyButton {
            style: root.style
            text: "Web UI"
            enabled: root.host.service.online && !root.controller.blocked
            onClicked: root.host.service.openWebUi()
        }
        SharedWidgetBusyButton {
            style: root.style
            text: "Rescan all"
            busyText: "Rescanning"
            busy: root.host.service.busy && root.host.service._actionName === "folder.rescan-all"
            enabled: root.host.service.online && !root.controller.blocked
            onClicked: root.host.service.rescanAllFolders()
        }
        SharedWidgetSquareActionButton {
            style: root.style
            text: "Refresh"
            actionIcon: "refresh"
            busyText: "Refreshing"
            busy: root.host.service.refreshing
            enabled: !root.controller.blocked
            help: "Refresh status and recheck reported folder errors"
            onClicked: root.host.service.refreshStatus()
        }
        SharedWidgetSquareActionButton {
            objectName: "settings"
            style: root.style
            text: "Settings"
            actionIcon: "settings"
            onClicked: source => {
                root.controller.rememberTrigger(source);
                root.host.settings.begin();
            }
        }
    }
}
