pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.components.controls
import "."
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var controller
    signal browseRequested
    InlineFormHeader {
        Layout.fillWidth: true
        title: root.controller.view.draft.pendingDeviceId ? "Accept folder" : "Add folder"
        busy: root.controller.busy
        onCancelled: root.controller.cancelForm()
    }
    StyledTextField {
        objectName: "syncshellInitialFocus"
        Layout.fillWidth: true
        placeholderText: "Directory"
        text: root.controller.view.draft.path || ""
        readOnly: root.controller.busy || !!root.controller.view.confirmation
        onTextEdited: root.controller.draft({
            path: text
        })
    }
    BusyButton {
        caption: "Browse directories"
        disabled: root.controller.busy
        onClicked: root.browseRequested()
    }
    StyledTextField {
        Layout.fillWidth: true
        placeholderText: "Label"
        text: root.controller.view.draft.label || ""
        readOnly: root.controller.busy || !!root.controller.view.confirmation
        onTextEdited: root.controller.draft({
            label: text
        })
    }
    StyledTextField {
        Layout.fillWidth: true
        placeholderText: "Folder ID"
        text: root.controller.view.draft.folderId || ""
        readOnly: root.controller.busy || !!root.controller.view.draft.pendingDeviceId || !!root.controller.view.confirmation
        onTextEdited: root.controller.draft({
            folderId: text
        })
    }
    BusyButton {
        caption: "Generate ID"
        disabled: root.controller.busy || !!root.controller.view.draft.pendingDeviceId
        onClicked: root.controller.service.requestFolderIdSuggestion()
    }
    StyledText {
        text: "Share with selected devices"
    }
    SyncshellDropdown {
        Layout.fillWidth: true
        multiple: true
        disabled: root.controller.busy || !!root.controller.view.confirmation
        options: root.controller.service.shareableDevices().map(d => ({
                    value: d.id,
                    label: d.name || d.id,
                    detail: d.id
                }))
        selectedIds: root.controller.view.draft.deviceIds || []
        onToggled: id => root.controller.draft({
                deviceIds: Model.toggle(selectedIds, id)
            })
    }
    StyledText {
        Layout.fillWidth: true
        text: "Existing files are kept. Missing directories require confirmation."
        wrapMode: Text.Wrap
    }
    BusyButton {
        caption: "Add folder"
        busy: root.controller.busy
        onClicked: root.controller.submitForm()
    }
}
