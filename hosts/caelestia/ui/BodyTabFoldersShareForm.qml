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
    readonly property var options: root.controller.service.shareableDevices().map(d => ({
                value: d.id,
                label: d.name || d.id,
                detail: d.id
            }))
    BodyFormHeader {
        Layout.fillWidth: true
        title: "Share " + root.controller.service.folderLabel(root.controller.view.draft.folderId)
        busy: root.controller.busy
        onCancelled: root.controller.cancelForm()
    }
    StyledText {
        Layout.fillWidth: true
        visible: root.options.length === 0
        text: "No remote devices available. Add a remote device below."
        font: Tokens.font.label.medium
        color: Model.statusColour(Colours.palette, "warning")
        wrapMode: Text.Wrap
    }
    StyledText {
        visible: root.options.length > 0
        text: "Share with devices"
        font: Tokens.font.label.medium
        color: Colours.palette.m3onSurfaceVariant
    }
    SharedWidgetDropdown {
        Layout.fillWidth: true
        visible: root.options.length > 0
        multiple: true
        placeholder: "Local only"
        disabled: root.controller.busy || !!root.controller.view.confirmation
        options: root.options
        selectedIds: root.controller.view.draft.deviceIds || []
        onToggled: id => root.controller.draft({
                deviceIds: Model.toggle(selectedIds, id)
            })
    }
    SharedWidgetBusyButton {
        Layout.fillWidth: true
        visible: root.options.length > 0
        caption: "Save sharing"
        primary: true
        busyCaption: "Saving..."
        busy: root.controller.busy
        onClicked: root.controller.submitForm()
    }
}
