import QtQuick
import QtQuick.Layouts
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var style
    required property var controller
    required property var folder
    readonly property var service: controller.service
    readonly property var displayStatus: Model.folderDisplay(folder, service.online && service.connection.fresh,
        service.busy && service._actionName === "folder.rescan" && service._actionTargetId === folder.id)
    readonly property var status: folder.status || ({})
    spacing: style.spacing
    NativeText {
        style: root.style
        Layout.fillWidth: true
        text: root.folder.label || Model.basename(root.folder.path)
    }
    InfoPair {
        style: root.style
        Layout.fillWidth: true
        label: "Status"
        value: root.displayStatus.label
        tone: root.displayStatus.role
    }
    InfoPair {
        style: root.style
        Layout.fillWidth: true
        label: "Path"
        value: root.folder.path
    }
    InfoPair {
        style: root.style
        Layout.fillWidth: true
        label: "Contents"
        value: (root.status.globalFiles || 0) + " files · " + Model.bytes(root.status.globalBytes)
    }
    InfoPair {
        style: root.style
        Layout.fillWidth: true
        label: "Remaining"
        value: (root.status.needTotalItems || 0) + " items · " + Model.bytes(root.status.needBytes)
    }
    Loader {
        id: progress
        Layout.fillWidth: true
        visible: root.status.needTotalItems > 0 && root.status.globalBytes > 0
        sourceComponent: root.style.progress
        Binding {
            target: progress.item
            property: "value"
            value: Math.max(0, 1 - Number(root.status.needBytes || 0) / Math.max(1, Number(root.status.globalBytes || 1)))
        }
    }
    ActivityText {
        style: root.style
        service: root.service
        folderId: root.folder.id
        Layout.fillWidth: true
    }
    Repeater {
        model: root.folder.devices || []
        NativeText {
            required property var modelData
            style: root.style
            Layout.fillWidth: true
            visible: modelData.id !== root.service.localDeviceId
            readonly property var share: Model.shareDisplay(modelData, root.service.device(modelData.id), root.service.online && root.service.connection.fresh)
            text: root.service.deviceName(modelData.id) + " · " + share.label
            tone: share.role
        }
    }
    NativeText {
        style: root.style
        Layout.fillWidth: true
        text: root.displayStatus.help
        muted: true
    }
    NativeText {
        style: root.style
        Layout.fillWidth: true
        text: (root.folder.devices || []).filter(row => row.id !== root.service.localDeviceId).length
            ? "Shared with remote devices listed above" : "Local only: no remote devices selected"
        muted: true
    }
    BusyButton {
        objectName: "folder-errors"
        style: root.style
        text: "Show affected paths and errors"
        visible: root.displayStatus.hasErrors
        tone: "danger"
        onClicked: root.controller.showDiagnostics(root.folder.id)
    }
    Flow {
        Layout.fillWidth: true
        spacing: 4
        BusyButton {
            style: root.style
            text: "Rescan"
            enabled: root.service.online && !root.folder.paused && !root.controller.blocked
            busy: root.service.busy && root.service._actionName === "folder.rescan" && root.service._actionTargetId === root.folder.id
            busyText: "Rescanning"
            onClicked: root.service.rescanFolder(root.folder.id)
        }
        BusyButton {
            style: root.style
            text: "Open"
            onClicked: Qt.openUrlExternally("file://" + root.folder.path.split("/").map(encodeURIComponent).join("/"))
        }
        IdCopyButton {
            controller: root.controller
            style: root.style
            value: root.folder.id
        }
        BusyButton {
            style: root.style
            text: "Forget"
            enabled: root.folder.paused === true && root.service.online && !root.controller.blocked
            tone: "danger"
            help: "Pause this folder before forgetting it. Files are kept."
            onClicked: source => {
                root.controller.rememberTrigger(source);
                root.controller.ask("folder.forget", {
                    folderId: root.folder.id
                }, "Forget " + root.folder.label + "?", "Remove this folder from Syncthing. Directory contents are kept.\n" + root.folder.path);
            }
        }
    }
    NativeText {
        style: root.style
        Layout.fillWidth: true
        text: root.status.error || ""
        visible: text !== ""
    }
    Repeater {
        model: root.status.errors || []
        NativeText {
            required property var modelData
            style: root.style
            Layout.fillWidth: true
            text: modelData.path + ": " + modelData.error
        }
    }
    BusyButton {
        style: root.style
        text: "Recheck errors"
        visible: Model.folderGroup(root.folder, true) === "errors"
        enabled: root.service.online && !root.controller.blocked
        busy: root.service.busy && root.service._actionName === "folder.recheck-errors"
        busyText: "Rechecking errors"
        onClicked: root.service.recheckErrors()
    }
}
