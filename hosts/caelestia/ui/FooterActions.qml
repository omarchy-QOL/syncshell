pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."

ColumnLayout {
    id: root
    required property var controller
    readonly property Item settingsTrigger: settingsButton
    signal settingsRequested(Item trigger)
    SharedWidgetBusyButton {
        caption: "Web UI"
        help: "Open the Syncthing Web UI"
        disabled: !root.controller.service.online || root.controller.busy
        onClicked: root.controller.service.openWebUi()
    }
    RowLayout {
        Layout.fillWidth: true
        SharedWidgetBusyButton {
            caption: "Rescan all"
            busyCaption: "Rescanning..."
            busy: root.controller.service.busy && root.controller.service._actionName === "folder.rescan-all"
            help: !root.controller.fresh ? "Refresh current status before rescanning" : "Rescan every linked folder"
            disabled: !root.controller.fresh || root.controller.busy || !root.controller.service.folders.some(f => !f.paused)
            onClicked: root.controller.service.rescanAllFolders()
        }
        SharedWidgetBusyButton {
            caption: "Refresh"
            busy: root.controller.service.refreshing
            disabled: root.controller.service.busy
            onClicked: root.controller.service.refresh()
        }
        Item {
            Layout.fillWidth: true
        }
        SharedWidgetSquareActionButton {
            id: settingsButton
            icon: "settings"
            help: "Settings"
            disabled: root.controller.busy
            onClicked: root.settingsRequested(settingsButton)
        }
    }
}
