pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."

ColumnLayout {
    id: root
    required property var controller
    readonly property Item settingsTrigger: settingsButton
    signal settingsRequested(Item trigger)
    RowLayout {
        SharedWidgetBusyButton {
            caption: "Web UI"
            help: "Open the Syncthing Web UI"
            disabled: !root.controller.service.online || root.controller.busy
            onClicked: root.controller.service.openWebUi()
        }
        // Omarchy's placeholders: visible, inactive, with a tooltip.
        Repeater {
            model: ["TUI", "GUI"]
            SharedWidgetBusyButton {
                required property string modelData
                caption: modelData
                help: "To be added soon."
                // Disabled look and no clicks, but enabled so hover shows the tooltip.
                disabled: true
                enabled: true
                activeFocusOnTab: false
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        SharedWidgetBusyButton {
            Layout.fillWidth: true
            caption: "Rescan all folders"
            busyCaption: "Rescanning..."
            busy: root.controller.service.busy && root.controller.service._actionName === "folder.rescan-all"
            help: !root.controller.fresh ? "Refresh current status before rescanning" : "Rescan all folders for local changes."
            disabled: !root.controller.fresh || root.controller.busy || !root.controller.service.folders.some(f => !f.paused)
            onClicked: root.controller.service.rescanAllFolders()
        }
        SharedWidgetBusyButton {
            Layout.fillWidth: true
            caption: "Refresh Sync.status"
            busyCaption: "Rechecking Syncthing"
            help: "Request latest Syncthing state.\nActive folders with current errors\nrescanned and errors rechecked."
            busy: root.controller.service.refreshing || root.controller.service.busy && root.controller.service._actionName === "folder.recheck-errors"
            disabled: root.controller.service.busy
            // Omarchy rechecks folder errors instead of a plain refresh when any exist.
            onClicked: root.controller.service.folderProblemCount > 0 ? root.controller.service.recheckErrors() : root.controller.service.refresh()
        }
        SharedWidgetSquareActionButton {
            id: settingsButton
            icon: "settings"
            help: "Syncshell settings"
            disabled: root.controller.busy
            onClicked: root.settingsRequested(settingsButton)
        }
    }
}
