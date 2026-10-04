import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
    id: root

    property var device: ({})
    property bool online: false
    property bool mutationBusy: false
    property bool actionBusy: false
    property string stateLabel: "DISCONNECTED"
    property color stateColor: Color.muted
    property color foreground: Color.foreground
    property color dim: Qt.darker(foreground, 1.5)
    required property color warning
    property string fontFamily: Style.font.family
    property var controller
    property Item keyboardCursor: null

    readonly property color cardBorderColor: device && device.paused ? warning : dim
    readonly property int sharedFolderCount: device && device.folderIds ? device.folderIds.length : 0
    readonly property int totalFolderCount: controller && controller.folderRows ? controller.folderRows.length : 0
    readonly property var keyboardRows: [[editDeviceButton, copyIdButton], [deviceActionButton]]

    signal actionHovered(Item action)
    signal editRequested
    signal pauseRequested(bool paused)

    function formatRate(value) {
        return controller.formatBytes(Math.max(0, Number(value || 0))) + "/s";
    }

    implicitHeight: nameActions.implicitHeight + details.implicitHeight + Style.space(14)
    color: "transparent"
    borderSpec: Border.controlSpec("normal", cardBorderColor, Color.accent)
    radius: Style.cornerRadius

    Row {
        id: nameActions
        z: 1
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: Style.space(2)

        TooltipButton {
            id: editDeviceButton
            width: Math.min(implicitWidth, Math.max(Style.space(48), root.width - stateBadge.width - copyIdButton.width - nameActions.spacing - Style.space(8)))
            clip: true
            iconText: "\uf108"
            text: String(root.device.name || "Unnamed device")
            helpText: "Open this device in the Web UI"
            bordered: true
            leftAlign: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.body
            iconSize: Style.font.body
            horizontalPadding: Style.space(6)
            verticalPadding: Style.space(2)
            enabled: root.online
            hasCursor: root.keyboardCursor === editDeviceButton
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(editDeviceButton);
            }
            onClicked: root.editRequested()
        }

        IdCopyButton {
            id: copyIdButton
            variant: "panel"
            size: editDeviceButton.implicitHeight
            value: String(root.device.id || "")
            notice: "Remote device ID copied"
            helpText: "Copy device ID"
            controller: root.controller
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            hasCursor: root.keyboardCursor === copyIdButton
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(copyIdButton);
            }
        }
    }

    BorderSurface {
        id: stateBadge
        z: 1
        anchors.right: parent.right
        anchors.top: parent.top
        implicitWidth: stateText.implicitWidth + Style.space(10)
        width: implicitWidth
        height: nameActions.height
        color: "transparent"
        borderSpec: Border.withWidth(Border.controlSpec("normal", root.stateColor, Color.accent), "0 0 1 1")
        radius: 0

        Text {
            id: stateText
            anchors.centerIn: parent
            text: root.stateLabel
            textFormat: Text.PlainText
            color: root.stateColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
        }
    }

    Column {
        id: details
        z: 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: nameActions.bottom
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: deviceActionButton.width + Style.space(14)
        anchors.topMargin: Style.space(6)
        spacing: Style.space(1)

        Text {
            width: parent.width
            text: "\uf07b  " + root.sharedFolderCount + "/" + root.totalFolderCount + " folder" + (root.totalFolderCount === 1 ? "" : "s") + " shared"
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
        }

        Row {
            width: parent.width
            spacing: Style.space(10)

            Text {
                text: "\uf019  " + root.formatRate(root.device.downloadBps)
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
            }

            Text {
                text: "\uf093  " + root.formatRate(root.device.uploadBps)
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
            }
        }

        Text {
            width: parent.width
            text: "\uf0e8  " + String(root.device.address || "Address unavailable")
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideLeft
        }
    }

    BusyButton {
        id: deviceActionButton
        z: 1
        visible: root.device
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: implicitWidth
        height: editDeviceButton.height
        iconText: root.device.paused ? "\uf04b" : "\uf04c"
        text: root.device.paused ? "RESUME" : "PAUSE"
        busyText: root.device.paused ? "RESUMING" : "PAUSING"
        busy: root.actionBusy
        tooltipText: root.device.paused ? "Resume synchronization with this device" : "Pause synchronization with this device"
        bordered: true
        foreground: root.foreground
        busyForeground: root.warning
        fontFamily: root.fontFamily
        fontSize: Style.font.body
        iconSize: Style.font.body
        horizontalPadding: Style.space(6)
        verticalPadding: Style.space(2)
        canActivate: root.online && !root.mutationBusy
        hasCursor: root.keyboardCursor === deviceActionButton
        onHovered: function (hovered) {
            if (hovered)
                root.actionHovered(deviceActionButton);
        }
        onClicked: root.pauseRequested(!root.device.paused)
    }
}
