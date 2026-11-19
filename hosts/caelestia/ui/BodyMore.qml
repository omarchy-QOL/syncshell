pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import "."
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var controller
    SharedWidgetInfoPair {
        Layout.fillWidth: true
        label: "Syncthing status"
        value: root.controller.service.summaryText
    }
    StyledText {
        Layout.fillWidth: true
        visible: !root.controller.fresh
        text: "Last reported errors; current status is unavailable"
        wrapMode: Text.Wrap
    }
    StyledText {
        Layout.fillWidth: true
        text: "Syncthing " + (root.controller.service.identity.version || "unknown") + " · " + (root.controller.service.installation.available ? "installed" : "not found")
        textFormat: Text.PlainText
        elide: Text.ElideRight
    }
    StyledText {
        Layout.fillWidth: true
        visible: !root.controller.service.canControlService
        text: root.controller.service.lifecycle.error || "Externally managed. Start Syncthing using its service manager, or authorize its exact unit in settings."
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    StyledText {
        Layout.fillWidth: true
        visible: !root.controller.service.installation.available
        text: "Install Syncthing using your distribution's package manager, start it, then Refresh."
        wrapMode: Text.Wrap
    }
    Repeater {
        model: root.controller.service.folders.filter(f => Model.hasErrors(f))
        StyledText {
            required property var modelData
            Layout.fillWidth: true
            text: Model.label(modelData) + "\nAffected: " + (modelData.path || modelData.id) + "\n" + Model.errorDetails(modelData)
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
    }
    StyledText {
        Layout.fillWidth: true
        text: Object.values(root.controller.service.truncation).some(n => n > 0) ? "Some entries are omitted by the core's display limits. Inspect the full list in Web UI." : ""
        visible: !!text
        wrapMode: Text.Wrap
    }
    SharedWidgetBusyButton {
        caption: "Recheck errors"
        busy: root.controller.busy
        disabled: busy || !root.controller.fresh
        onClicked: root.controller.service.recheckErrors()
    }
}
