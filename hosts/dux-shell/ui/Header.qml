import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets
import "../models/PanelModel.js" as Model
import "UiConstants.js" as UiConstants

ColumnLayout {
    id: root
    required property var controller
    property string iconStyle: "themed"
    readonly property var service: controller.service
    readonly property var totals: Model.totals(service ? service.folders : [])
    RowLayout {
        Layout.fillWidth: true
        SharedWidgetMonoIcon {
            size: 36
            variant: Model.statusVariant(root.service)
            themed: root.iconStyle === "themed"
            opacity: !root.service || !root.service.online || variant === "pause" ? 0.5 : 1
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                text: "Syncthing"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
            }
            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: root.service ? root.service.deviceName(root.service.localDeviceId) : "Starting"
                    textFormat: Text.PlainText
                    wrapMode: Text.NoWrap
                    Layout.preferredWidth: implicitWidth
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }
                SharedWidgetIdCopyButton {
                    value: root.service ? root.service.localDeviceId : ""
                    caption: "device ID"
                    helpText: "Copy device ID"
                }
            }
        }
        Item {
            Layout.fillWidth: true
        }
        // Omarchy hides the toggle when this host may not control the service.
        DToggle {
            visible: !!root.service && root.service.canControlService
            hideText: true
            checked: !!root.service && root.service.lifecycle.active === true
            enabled: !!root.service && root.service.canControlService && !root.controller.busy && !root.controller.form && !root.controller.confirmation
            onToggled: root.controller.requestServiceToggle(this)
            SharedWidgetToolTip {
                anchors.fill: parent
                text: root.service && root.service.canControlService ? "Start or stop Syncthing without changing autostart" : "Externally managed. Authorize the matching user service in Syncshell settings to control it here."
            }
        }
    }
    SharedWidgetInfoPair {
        Layout.fillWidth: true
        label: "Folders"
        value: root.service ? String(root.service.folderCount) : "-"
    }
    SharedWidgetInfoPair {
        Layout.fillWidth: true
        label: "Devices"
        value: root.controller.fresh ? root.service.connectedDeviceCount + " of " + root.service.deviceCount + " connected" : "Connection unknown"
    }
    SharedWidgetInfoPair {
        Layout.fillWidth: true
        label: "Tracked"
        value: Model.formatCount(root.totals.files) + " files · " + Model.bytes(root.totals.bytes)
    }
    StyledText {
        Layout.fillWidth: true
        text: root.service ? root.service.lastError || (!root.service.online ? root.service.summaryText : "") : "Starting Syncshell"
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        visible: text !== ""
        color: root.service && root.service.lastError ? Theme.error : Theme.onSurfaceVariant
    }
    // Omarchy shows an action notice in green for a while, then fades it out
    // instead of keeping it in the header.
    property string shownNotice: ""
    property bool noticeShown: false
    Connections {
        target: root.service
        function onActionNoticeChanged() {
            if (!root.service.actionNotice)
                return;
            root.shownNotice = root.service.actionNotice;
            root.noticeShown = true;
            noticeFade.stop();
            noticeDisplay.restart();
        }
    }
    Timer {
        id: noticeDisplay
        interval: UiConstants.NOTICE_VISIBLE_MS
        onTriggered: {
            root.noticeShown = false;
            noticeFade.restart();
        }
    }
    Timer {
        id: noticeFade
        interval: UiConstants.NOTICE_FADE_MS
        onTriggered: if (!root.noticeShown)
            root.shownNotice = ""
    }
    StyledText {
        Layout.fillWidth: true
        visible: root.shownNotice !== ""
        text: root.shownNotice
        textFormat: Text.PlainText
        color: Theme.success
        opacity: root.noticeShown ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: root.noticeShown ? 0 : UiConstants.NOTICE_FADE_MS
                easing.type: Easing.OutCubic
            }
        }
    }
}
