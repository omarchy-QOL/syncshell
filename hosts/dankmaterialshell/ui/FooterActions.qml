import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

ColumnLayout {
    id: root
    required property var controller
    property string pluginId: "syncshell"
    signal settingsOpening
    function openSettings() {
        settings.clicked();
    }
    spacing: Theme.spacingS
    DankButton {
        text: "Web UI"
        enabled: !!root.controller.service && root.controller.service.online && !root.controller.busy
        onClicked: root.controller.service.openWebUi()
    }
    RowLayout {
        Layout.fillWidth: true
        SharedWidgetBusyButton {
            Layout.fillWidth: true
            text: "Rescan all"
            busyText: "Rescanning"
            busy: !!root.controller.service && root.controller.service.busy && root.controller.service._actionName === "folder.rescan-all"
            enabled: root.controller.fresh && !root.controller.busy && root.controller.service.folders.some(f => !f.paused)
            help: !root.controller.fresh ? "Refresh current status before rescanning" : "Rescan every linked folder; paused folders are skipped"
            onClicked: root.controller.service.rescanAllFolders()
        }
        SharedWidgetBusyButton {
            Layout.fillWidth: true
            text: "Refresh"
            busy: !!root.controller.service && root.controller.service.refreshing
            enabled: !!root.controller.service && !root.controller.busy
            onClicked: root.controller.service.refresh()
        }
        FooterSettingsButton {
            id: settings
            pluginId: root.pluginId
            onOpening: root.settingsOpening()
        }
    }
}
