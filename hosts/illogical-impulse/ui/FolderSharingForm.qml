import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var style
    required property var controller
    InlineFormHeader {
        style: root.style
        Layout.fillWidth: true
        title: "Folder sharing"
        enabled: !root.controller.pending
        onCanceled: root.controller.discard()
    }
    NativeText {
        style: root.style
        Layout.fillWidth: true
        text: root.controller.draft.folderId || ""
    }
    SyncshellMultiSelect {
        id: choices
        enabled: !root.controller.blocked
        style: root.style
        controller: root.controller
        Layout.fillWidth: true
        selectorKey: "sharing"
        label: "Devices"
        selectedIds: root.controller.draft.deviceIds || []
        options: root.controller.service.shareableDevices().map(device => ({
                    id: device.id,
                    label: device.name || device.id,
                    description: device.id
                }))
        onChanged: ids => root.controller.edit("deviceIds", ids)
    }
    NativeText {
        style: root.style
        Layout.fillWidth: true
        text: "Clear every selection to stop sharing with all remote devices. Files remain on each device."
    }
    NativeText {
        style: root.style
        Layout.fillWidth: true
        muted: true
        text: root.controller.service.shareableDevices().length === 0
            ? "No remote devices configured. Add a device before sharing this folder."
            : (root.controller.draft.deviceIds || []).length === 0 ? "Local only: this folder is not shared with a remote device."
            : "Newly selected devices receive an invitation and must accept it."
    }
    BusyButton {
        style: root.style
        objectName: "save-sharing"
        text: "Save sharing"
        busyText: "Saving sharing"
        busy: root.controller.pending
        enabled: root.controller.service.online && !root.controller.blocked && !root.controller.targetMissing
        onClicked: root.controller.save()
    }
    Component.onCompleted: Qt.callLater(choices.focusControl)
    Connections {
        target: root.controller
        function onFocusRequested(key) {
            if (key === "first-field")
                choices.focusControl();
        }
    }
}
