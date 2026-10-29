import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import "UiConstants.js" as UiConstants

ColumnLayout {
    id: root
    required property var controller
    property string pluginId: "syncshell"
    property bool settingsWaiting: false
    signal settingsOpening
    // DMS owns plugin settings in its own window; the gear opens them there
    // instead of Omarchy's in-panel SettingsMenu.
    function openSettings() {
        settingsOpening();
        settingsWaiting = true;
        PopoutService.openSettingsWithTab("plugins");
        finishSettings();
    }
    function finishSettings() {
        if (settingsWaiting && PopoutService.settingsModal) {
            PopoutService.settingsModal.openPluginSettings(pluginId);
            settingsWaiting = false;
        }
    }
    spacing: UiConstants.SECTION_SPACING
    Connections {
        target: PopoutService
        function onSettingsModalChanged() {
            root.finishSettings();
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Theme.outlineWidth
        color: Theme.outlineVariant
    }
    Row {
        spacing: Theme.spacingS
        SharedWidgetTooltipButton {
            text: "Web UI"
            iconName: "open_in_new"
            help: "Open the Syncthing Web UI"
            enabled: !!root.controller.service && root.controller.service.online && !root.controller.busy
            onClicked: root.controller.service.openWebUi()
        }
        Repeater {
            model: ["TUI", "GUI"]
            SharedWidgetTooltipButton {
                required property string modelData
                text: modelData
                help: "To be added soon."
                canActivate: false
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingS
        // Equal halves: natural widths shift with busy captions and starved
        // the rescan label.
        SharedWidgetBusyButton {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            text: "Rescan all folders"
            busyText: "Rescanning..."
            iconName: "refresh"
            busy: !!root.controller.service && root.controller.service.busy && root.controller.service._actionName === "folder.rescan-all"
            enabled: root.controller.fresh && !root.controller.busy && root.controller.service.folders.some(f => !f.paused)
            help: !root.controller.fresh ? "Refresh current status before rescanning" : "Rescan all folders for local changes."
            onClicked: root.controller.service.rescanAllFolders()
        }
        SharedWidgetBusyButton {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            text: "Refresh Sync.status"
            busyText: "Rechecking Syncthing"
            iconName: "monitor_heart"
            help: "Request latest Syncthing state.\nActive folders with current errors\nrescanned and errors rechecked."
            busy: !!root.controller.service && (root.controller.service.refreshing || root.controller.service.busy && root.controller.service._actionName === "folder.recheck-errors")
            enabled: !!root.controller.service && !root.controller.busy
            // Omarchy rechecks folder errors instead of a plain refresh when any exist.
            onClicked: root.controller.service.folderProblemCount > 0 ? root.controller.service.recheckErrors() : root.controller.service.refresh()
        }
        SharedWidgetSquareActionButton {
            iconName: "settings"
            help: "Syncshell settings"
            onClicked: root.openSettings()
        }
    }
}
