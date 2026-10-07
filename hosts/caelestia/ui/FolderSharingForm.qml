pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import "."
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var controller
    InlineFormHeader {
        Layout.fillWidth: true
        title: "Folder sharing"
        busy: root.controller.busy
        onCancelled: root.controller.cancelForm()
    }
    StyledText {
        Layout.fillWidth: true
        text: root.controller.service.folderLabel(root.controller.view.draft.folderId)
        wrapMode: Text.Wrap
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
        text: "New devices receive a share offer. Unchecked devices lose this share; their files are kept. Encrypted sharing is managed in Web UI."
        wrapMode: Text.Wrap
    }
    BusyButton {
        caption: "Review sharing"
        busy: root.controller.busy
        onClicked: root.controller.submitForm()
    }
}
