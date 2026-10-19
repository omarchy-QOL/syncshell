import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var host
    readonly property var controller: host.controller
    readonly property var style: host.style
    spacing: style.spacing
    Loader {
        Layout.fillWidth: true
        active: root.controller.confirmationVisible
        visible: active
        sourceComponent: confirm
    }
    Loader {
        Layout.fillWidth: true
        visible: !root.controller.confirmationVisible
        sourceComponent: root.host.settings.opened ? settings : root.controller.view === "add-folder" ? addFolder : root.controller.view === "add-device" ? addDevice : root.controller.view === "accept-device" ? acceptDevice : root.controller.view === "share-folder" ? shareFolder : root.controller.view === "device-folders" ? deviceFolders : null
    }
    NativeText {
        style: root.style
        Layout.fillWidth: true
        text: root.controller.error
        visible: text !== ""
    }
    NativeText {
        style: root.style
        Layout.fillWidth: true
        text: "The target is no longer available. Cancel this draft to choose another."
        visible: root.controller.targetMissing
    }
    Component {
        id: confirm
        CompactConfirmDialog {
            style: root.style
            controller: root.controller
        }
    }
    Component {
        id: settings
        SettingsMenu {
            host: root.host
        }
    }
    Component {
        id: addFolder
        AddFolderForm {
            style: root.style
            controller: root.controller
        }
    }
    Component {
        id: addDevice
        AddRemoteDeviceForm {
            style: root.style
            controller: root.controller
        }
    }
    Component {
        id: acceptDevice
        AcceptRemoteDeviceForm {
            style: root.style
            controller: root.controller
        }
    }
    Component {
        id: shareFolder
        FolderSharingForm {
            style: root.style
            controller: root.controller
        }
    }
    Component {
        id: deviceFolders
        DeviceFoldersForm {
            style: root.style
            controller: root.controller
        }
    }
}
