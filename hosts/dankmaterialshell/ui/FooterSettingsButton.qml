import QtQuick
import qs.Services

SharedWidgetSquareActionButton {
    id: root
    property string pluginId: "syncshell"
    property bool waiting: false
    signal opening
    iconName: "settings"
    help: "Syncshell settings"
    function finishOpen() {
        if (waiting && PopoutService.settingsModal) {
            PopoutService.settingsModal.openPluginSettings(pluginId);
            waiting = false;
        }
    }
    onClicked: {
        opening();
        waiting = true;
        PopoutService.openSettingsWithTab("plugins");
        finishOpen();
    }
    Connections {
        target: PopoutService
        function onSettingsModalChanged() {
            root.finishOpen();
        }
    }
}
