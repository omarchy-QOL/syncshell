pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import "."
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var controller
    readonly property var totals: Model.totals(controller.service.folders)
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
            disabled: root.controller.busy || !!root.controller.view.form || !!root.controller.view.confirmation || !root.controller.service.canControlService
            onToggled: {
                root.controller.requestServiceToggle();
                checked = Qt.binding(() => root.controller.service.lifecycle.active === true);
            }
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
            copyValue: root.controller.service.localDeviceId
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
    StyledText {
        Layout.fillWidth: true
        text: root.totals.files + " files · " + Model.bytes(root.totals.bytes) + " tracked"
        wrapMode: Text.Wrap
    }
}
