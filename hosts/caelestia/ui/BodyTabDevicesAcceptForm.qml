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
    component Caption: StyledText {
        font: Tokens.font.label.medium
        color: Colours.palette.m3onSurfaceVariant
    }
    BodyFormHeader {
        Layout.fillWidth: true
        title: "Accept remote device request"
        busy: root.controller.busy
        onCancelled: root.controller.cancelForm()
    }
    RowLayout {
        Layout.fillWidth: true
        Caption {
            text: "Name"
        }
        StyledTextField {
            Layout.fillWidth: true
            objectName: "syncshellInitialFocus"
            placeholderText: "Optional name"
            text: root.controller.view.draft.deviceName || ""
            readOnly: root.controller.busy
            onTextEdited: root.controller.draft({
                deviceName: text
            })
        }
    }
    SharedWidgetInfoPair {
        Layout.fillWidth: true
        label: "Observed address"
        value: root.controller.view.draft.address || "unknown"
    }
    RowLayout {
        Layout.fillWidth: true
        SharedWidgetInfoPair {
            Layout.fillWidth: true
            label: "Device ID"
            value: root.controller.view.draft.deviceId || ""
        }
        SharedWidgetIdCopyButton {
            value: root.controller.view.draft.deviceId || ""
            caption: ""
            help: "Copy device ID"
        }
    }
    SharedWidgetBusyButton {
        Layout.fillWidth: true
        caption: "Accept remote device connection"
        primary: true
        busyCaption: "Accepting..."
        busy: root.controller.busy
        onClicked: root.controller.submitForm()
    }
}
