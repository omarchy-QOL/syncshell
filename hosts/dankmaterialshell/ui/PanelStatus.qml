import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var controller
    property string iconStyle: "themed"
    readonly property var service: controller.service
    readonly property var totals: Model.totals(service ? service.folders : [])
    RowLayout {
        Layout.fillWidth: true
        DankSVGIcon {
            source: Qt.resolvedUrl("../../../assets/" + (root.iconStyle === "themed" ? "mono/" : "") + "status-default.svg")
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            colorOverride: root.iconStyle === "themed" ? Theme.surfaceText : "transparent"
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText { text: "Syncthing"; font.weight: Font.Medium }
            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: root.service ? root.service.deviceName(root.service.localDeviceId) : "Starting"
                    textFormat: Text.PlainText
                    maximumLineCount: 1
                    Layout.fillWidth: true
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
                IdCopyButton { value: root.service ? root.service.localDeviceId : "" }
            }
        }
        DankToggle {
            hideText: true
            checked: !!root.service && root.service.lifecycle.active === true
            enabled: !!root.service && root.service.canControlService && !root.controller.busy
            onToggled: checked => root.controller.requestConfirmation(
                checked ? "lifecycle.enable" : "lifecycle.disable", {}, this)
            SyncshellToolTip {
                anchors.fill: parent
                text: root.service && root.service.canControlService ? "Enable or disable Syncthing"
                    : "Externally managed. Authorize the matching user service in Syncshell settings to control it here."
            }
        }
    }
    InfoPair { Layout.fillWidth: true; label: "Folders"; value: root.service ? String(root.service.folderCount) : "-" }
    InfoPair {
        Layout.fillWidth: true
        label: "Devices"
        value: root.controller.fresh ? root.service.connectedDeviceCount
            + " of " + root.service.deviceCount + " connected" : "Connection unknown"
    }
    InfoPair {
        Layout.fillWidth: true
        label: "Tracked"
        value: root.totals.files + " files · " + Model.bytes(root.totals.bytes)
    }
    StyledText {
        Layout.fillWidth: true
        text: root.service ? root.service.lastError || root.service.actionNotice
            || (!root.service.online ? root.service.summaryText : "") : "Starting Syncshell"
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        visible: text !== ""
        color: root.service && root.service.lastError ? Theme.error : Theme.surfaceVariantText
    }
}
