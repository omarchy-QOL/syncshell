pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import "."

ColumnLayout {
    id: root
    required property var controller
    RowLayout {
        MaterialIcon {
            text: "sync"
            fontStyle: Tokens.font.icon.large
        }
        StyledText {
            Layout.fillWidth: true
            text: "Syncthing"
            font: Tokens.font.title.medium
        }
        StyledSwitch {
            checked: root.controller.service.lifecycle.active === true
            disabled: root.controller.busy || !root.controller.service.canControlService
            onToggled: root.controller.confirm(checked ? "lifecycle.start" : "lifecycle.stop", {}, checked ? "Start Syncthing?" : "Stop Syncthing?", "Change the running state of the verified systemd user service.")
        }
    }
    RowLayout {
        StyledText {
            Layout.fillWidth: true
            text: root.controller.service.device(root.controller.service.localDeviceId)?.name || "This device"
            elide: Text.ElideRight
        }
        BusyButton {
            caption: "Copy ID"
            disabled: !root.controller.service.localDeviceId
            onClicked: Quickshell.clipboardText = root.controller.service.localDeviceId
        }
    }
    StyledText {
        Layout.fillWidth: true
        text: root.controller.service.summaryText
        wrapMode: Text.Wrap
    }
    StyledText {
        text: root.controller.service.folderCount + " folders · " + root.controller.service.connectedDeviceCount + "/" + root.controller.service.deviceCount + " devices"
    }
}
