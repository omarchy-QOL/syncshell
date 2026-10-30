pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import "."
import "../models/PanelModel.js" as Model

// Omarchy's add-folder fields: captions above, browse and new ID inline.
ColumnLayout {
    id: root
    required property var controller
    readonly property bool locked: root.controller.busy || !!root.controller.view.confirmation
    readonly property var deviceIds: root.controller.view.draft.deviceIds || []
    signal browseRequested
    component Caption: StyledText {
        font: Tokens.font.label.medium
        color: Colours.palette.m3onSurfaceVariant
    }
    BodyFormHeader {
        Layout.fillWidth: true
        title: "Add folder"
        busy: root.controller.busy
        onCancelled: root.controller.cancelForm()
    }
    Caption {
        text: "Local directory"
    }
    RowLayout {
        Layout.fillWidth: true
        SharedWidgetTextField {
            objectName: "syncshellInitialFocus"
            Layout.fillWidth: true
            hint: "/path/to/my/folder"
            text: root.controller.view.draft.path || ""
            readOnly: root.locked
            onTextEdited: root.controller.draft({
                path: text
            })
        }
        SharedWidgetSquareActionButton {
            icon: "folder_open"
            help: "Choose an existing local directory"
            disabled: root.controller.busy
            onClicked: root.browseRequested()
        }
    }
    Caption {
        text: "Label"
    }
    SharedWidgetTextField {
        Layout.fillWidth: true
        hint: "Derived from the directory name when empty"
        text: root.controller.view.draft.label || ""
        readOnly: root.locked
        onTextEdited: root.controller.draft({
            label: text
        })
    }
    Caption {
        text: "Folder ID"
    }
    RowLayout {
        Layout.fillWidth: true
        SharedWidgetTextField {
            Layout.fillWidth: true
            hint: root.controller.idSuggestionPending ? "Generating..." : "Required folder identity"
            text: root.controller.view.draft.folderId || ""
            readOnly: root.locked || !!root.controller.view.draft.pendingDeviceId
            onTextEdited: root.controller.draft({
                folderId: text
            })
        }
        SharedWidgetSquareActionButton {
            icon: "refresh"
            help: "Generate a new Syncthing folder ID"
            disabled: root.locked || !!root.controller.view.draft.pendingDeviceId
            onClicked: root.controller.suggestFolderId()
        }
    }
    StyledText {
        Layout.fillWidth: true
        text: "Reuse the exact ID to rejoin an existing remote folder. A new ID creates a different folder identity."
        font: Tokens.font.label.medium
        color: Colours.palette.m3onSurfaceVariant
        wrapMode: Text.Wrap
    }
    Caption {
        text: "Share with devices"
    }
    SharedWidgetDropdown {
        Layout.fillWidth: true
        multiple: true
        placeholder: "Local only"
        disabled: root.locked
        options: root.controller.service.shareableDevices().map(d => ({
                    value: d.id,
                    label: d.name || d.id,
                    detail: d.id
                }))
        selectedIds: root.deviceIds
        onToggled: id => root.controller.draft({
                deviceIds: Model.toggle(selectedIds, id)
            })
    }
    StyledText {
        Layout.fillWidth: true
        text: root.deviceIds.length ? "Selected devices receive a share offer and may need to accept it." : "Local only: not shared with other devices."
        font: Tokens.font.label.medium
        color: Colours.palette.m3onSurfaceVariant
        wrapMode: Text.Wrap
    }
    SharedWidgetBusyButton {
        Layout.fillWidth: true
        caption: "Add folder"
        primary: true
        busyCaption: "Adding..."
        busy: root.controller.busy
        onClicked: root.controller.submitForm()
    }
}
