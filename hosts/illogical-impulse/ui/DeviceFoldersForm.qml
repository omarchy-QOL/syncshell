import QtQuick
import QtQuick.Layouts
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var style
    required property var controller
    readonly property var service: controller.service
    InlineFormHeader {
        style: root.style
        Layout.fillWidth: true
        title: "Device folders"
        enabled: !root.controller.pending
        onCanceled: root.controller.discard()
    }
    SyncshellMultiSelect {
        id: choices
        enabled: !root.controller.blocked
        style: root.style
        controller: root.controller
        Layout.fillWidth: true
        selectorKey: "device-folders"
        label: "Confirmed shares"
        help: "Shared back by the remote device; unchecked folders will stop sharing with it"
        selectedIds: root.controller.draft.folderIds || []
        options: Model.deviceFolderOptions(root.service.folders, root.service.device(root.controller.draft.deviceId), root.service.online && root.service.connection.fresh, false)
        onChanged: ids => root.controller.edit("folderIds", ids)
    }
    SyncshellMultiSelect {
        style: root.style
        controller: root.controller
        enabled: !root.controller.blocked
        Layout.fillWidth: true
        selectorKey: "unconfirmed-device-folders"
        label: "Unconfirmed shares"
        help: "Remote acceptance may be pending, or the device may be offline. Removing a share does not delete files."
        selectedIds: root.controller.draft.folderIds || []
        options: Model.deviceFolderOptions(root.service.folders, root.service.device(root.controller.draft.deviceId), root.service.online && root.service.connection.fresh, true)
        onChanged: ids => root.controller.edit("folderIds", ids)
    }
    NativeText {
        style: root.style
        Layout.fillWidth: true
        text: "Unchecked folders stop sharing with this device. Add new shares from a folder's Share action."
    }
    NativeText {
        objectName: "sharing-change-summary"
        style: root.style
        Layout.fillWidth: true
        muted: true
        text: root.controller.noSharingChange ? "No shares selected for removal"
            : root.controller.removedShareIds.length + " shares will be removed; files are kept"
    }
    BusyButton {
        style: root.style
        objectName: "save-sharing"
        text: "Save sharing"
        busyText: "Saving sharing"
        busy: root.controller.pending
        enabled: root.controller.service.online && !root.controller.blocked && !root.controller.targetMissing && !root.controller.noSharingChange
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
