import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var controller
    readonly property var service: controller.service
    spacing: Theme.spacingS
    // A flat disclosure row, as Omarchy's chevron More/Less.
    SharedWidgetTooltipButton {
        flat: true
        leftAlign: true
        text: root.controller.moreOpen ? "Less" : "More"
        iconName: root.controller.moreOpen ? "expand_less" : "expand_more"
        Accessible.name: root.controller.moreOpen ? "Hide details" : "Show details"
        onClicked: root.controller.moreOpen = !root.controller.moreOpen
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.controller.moreOpen
        spacing: Theme.spacingS
        SharedWidgetInfoPair {
            Layout.fillWidth: true
            label: "Syncthing status"
            value: root.controller.fresh ? "Current" : "Last reported errors; current status is unavailable"
        }
        SharedWidgetInfoPair {
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
                return Model.hasErrors(folder);
            }) : []
            StyledText {
                required property var modelData
                Layout.fillWidth: true
                text: (modelData.label || modelData.id) + "\nAffected: " + (modelData.path || modelData.id) + "\n" + Model.errorDetails(modelData)
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                color: Theme.error
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: "Some entries are omitted by the core's display limits. Open Web UI for the full list."
            visible: !!root.service && Object.values(root.service.truncation).some(n => n > 0)
            wrapMode: Text.Wrap
        }
        SharedWidgetBusyButton {
            text: "Recheck errors"
            busy: !!root.service && root.service.busy
            enabled: !!root.service && root.service.online
            onClicked: root.service.recheckErrors()
        }
    }
}
