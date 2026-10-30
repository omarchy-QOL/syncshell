pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import "."
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var controller
    property bool brandedIcon: false
    readonly property var service: controller.service
    readonly property var totals: Model.totals(service.folders)
    readonly property string iconVariant: Model.statusVariant(service)
    RowLayout {
        spacing: Tokens.spacing.medium
        Item {
            implicitWidth: Tokens.font.icon.large.pointSize * 2
            implicitHeight: implicitWidth
            opacity: root.iconVariant === "pause" || !root.service.online ? 0.5 : 1
            SharedWidgetMonoIcon {
                anchors.fill: parent
                visible: !root.brandedIcon
                source: Model.statusIconUrl(root.service.bundleRoot, root.iconVariant, true)
                tint: Colours.palette.m3onSurface
            }
            Image {
                anchors.fill: parent
                visible: root.brandedIcon
                source: root.brandedIcon ? Model.statusIconUrl(root.service.bundleRoot, root.iconVariant, false) : ""
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: "Syncthing"
                font: Tokens.font.title.medium
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                StyledText {
                    Layout.preferredWidth: implicitWidth
                    Layout.minimumWidth: 0
                    text: root.service.device(root.service.localDeviceId)?.name || "This device"
                    textFormat: Text.PlainText
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                    elide: Text.ElideRight
                }
                SharedWidgetIdCopyButton {
                    value: root.service.localDeviceId
                    caption: "device ID"
                    help: "Copy device ID"
                }
            }
        }
        // Omarchy hides the toggle when this host may not control the service.
        StyledSwitch {
            visible: root.service.canControlService
            checked: root.service.lifecycle.active === true
            disabled: root.controller.busy || !!root.controller.view.form || !!root.controller.view.confirmation
            onToggled: {
                root.controller.requestServiceToggle();
                checked = Qt.binding(() => root.service.lifecycle.active === true);
            }
        }
    }
    SharedWidgetInfoPair {
        Layout.fillWidth: true
        label: "Folders"
        value: String(root.service.folderCount)
    }
    SharedWidgetInfoPair {
        Layout.fillWidth: true
        label: "Devices"
        value: root.service.connectedDeviceCount + " of " + root.service.deviceCount + " connected"
    }
    SharedWidgetInfoPair {
        Layout.fillWidth: true
        label: "Tracked"
        value: Model.formatCount(root.totals.files) + " files · " + Model.bytes(root.totals.bytes)
    }
    // Omarchy shows an action notice in green for 10 s, then fades it out.
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
        interval: 10000
        onTriggered: {
            root.noticeShown = false;
            noticeFade.restart();
        }
    }
    Timer {
        id: noticeFade
        interval: 350
        onTriggered: if (!root.noticeShown)
            root.shownNotice = ""
    }
    StyledText {
        Layout.fillWidth: true
        visible: root.shownNotice !== ""
        text: root.shownNotice
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        font: Tokens.font.label.medium
        color: Colours.palette.m3success
        opacity: root.noticeShown ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: root.noticeShown ? 0 : 350
                easing.type: Easing.OutCubic
            }
        }
    }
}
