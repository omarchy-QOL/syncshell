import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

ColumnLayout {
    id: root
    required property var controller
    readonly property var service: controller.service
    spacing: Theme.spacingS
    DankButton {
        Layout.fillWidth: true
        text: root.controller.moreOpen ? "Less" : "More"
        iconName: root.controller.moreOpen ? "expand_less" : "expand_more"
        onClicked: root.controller.moreOpen = !root.controller.moreOpen
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.controller.moreOpen
        spacing: Theme.spacingS
        InfoPair {
            Layout.fillWidth: true
            label: "Syncthing status"
            value: root.controller.fresh ? "Current" : "Stale or unavailable"
        }
        InfoPair {
            Layout.fillWidth: true
            label: "Installation"
            value: root.service ? root.service.installation.executablePath || "Not found" : "Unknown"
        }
        StyledText {
            Layout.fillWidth: true
            visible: !!root.service && !root.service.installation.available
            text: "Install Syncthing with your distribution's package manager, then refresh."
            color: Theme.warning
        }
        StyledText {
            Layout.fillWidth: true
            text: root.service && root.service.lifecycle.error || ""
            visible: text !== ""
            textFormat: Text.PlainText
            color: Theme.warning
        }
        Repeater {
            model: root.service ? root.service.folders.filter(function (folder) {
                return folder.status && (folder.status.error || folder.status.pullErrors > 0);
            }) : []
            StyledText {
                required property var modelData
                Layout.fillWidth: true
                text: (modelData.label || modelData.id) + ": " + (modelData.status.error || "Sync errors")
                    + (modelData.status.errors || []).map(function (error) {
                        return "\n" + error.path + ": " + error.error;
                    }).join("")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                color: Theme.error
            }
        }
        BusyButton {
            text: "Recheck errors"
            busy: !!root.service && root.service.busy
            enabled: !!root.service && root.service.online
            onClicked: root.service.recheckErrors()
        }
    }
}
