import QtQuick
import QtQuick.Layouts
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var style
    required property var controller
    readonly property var service: controller.service
    readonly property bool accepting: !!controller.draft.pendingDeviceId
    spacing: style.spacing
    InlineFormHeader {
        style: root.style
        Layout.fillWidth: true
        title: root.accepting ? "Accept folder invitation" : "Add folder"
        enabled: !root.controller.pending
        onCanceled: root.controller.discard()
    }
    SyncshellDropdown {
        style: root.style
        controller: root.controller
        Layout.fillWidth: true
        selectorKey: "folder-offer"
        label: root.accepting ? "Invitation: " + root.controller.draft.folderId : "Use a folder invitation"
        selectedId: root.accepting ? Model.offerKey({folderId: root.controller.draft.folderId, deviceId: root.controller.draft.pendingDeviceId}) : ""
        options: root.controller.offerRows
        visible: options.length > 0 || root.accepting
        enabled: !root.controller.blocked
        help: "Choose the exact folder and offering device. Encrypted offers require the Web UI."
        onChosen: id => root.controller.chooseFolderOffer(id)
    }
    BusyButton {
        style: root.style
        text: "Open Web UI for encrypted invitations"
        visible: root.controller.offerRows.some(row => row.offer.encrypted)
        enabled: root.service.online && !root.controller.blocked
        onClicked: root.service.openWebUi()
    }
    FormField {
        id: path
        objectName: "folder-path"
        style: root.style
        Layout.fillWidth: true
        label: "Directory path"
        placeholder: "/home/you/Documents"
        text: root.controller.draft.path || ""
        readOnly: root.controller.pending
        help: "Choose an existing directory, or enter a new path and confirm its creation."
        onEdited: value => root.controller.edit("path", value)
        onAccepted: root.controller.save()
    }
    BusyButton {
        objectName: "browse-directory"
        style: root.style
        text: "Browse directory"
        enabled: !root.controller.blocked
        onClicked: root.controller.browseRequested()
    }
    FormField {
        objectName: "folder-id"
        style: root.style
        Layout.fillWidth: true
        label: "Folder ID"
        text: root.controller.draft.folderId || ""
        readOnly: root.controller.pending || root.accepting
        help: root.accepting ? "This identity belongs to the selected invitation. New ID leaves invitation mode."
            : "Use the same ID on every peer sharing this folder. The directory name can differ."
        onEdited: value => root.controller.edit("folderId", value)
        onAccepted: root.controller.save()
    }
    BusyButton {
        objectName: "new-folder-id"
        style: root.style
        text: "New ID"
        busy: root.controller.preparing
        busyText: "Preparing ID"
        enabled: root.service.online && !root.controller.blocked
        onClicked: root.controller.generateFolderId()
    }
    NativeText {
        objectName: "folder-preparation-error"
        style: root.style
        Layout.fillWidth: true
        text: root.controller.preparationError
        visible: text !== ""
        tone: "danger"
    }
    FormField {
        objectName: "folder-label"
        style: root.style
        Layout.fillWidth: true
        label: "Folder label (optional)"
        text: root.controller.draft.label || ""
        readOnly: root.controller.pending
        help: "Leave blank to use the directory name. Labels do not define sharing identity."
        onEdited: value => root.controller.edit("label", value)
        onAccepted: root.controller.save()
    }
    SyncshellMultiSelect {
        style: root.style
        controller: root.controller
        Layout.fillWidth: true
        selectorKey: "add-sharing"
        label: "Share with devices"
        selectedIds: root.controller.draft.deviceIds || []
        options: root.service.shareableDevices().map(device => ({
            id: device.id, label: device.name || device.id, description: device.id
        }))
        enabled: !root.controller.blocked
        onChanged: ids => root.controller.edit("deviceIds", ids)
    }
    NativeText {
        style: root.style
        Layout.fillWidth: true
        muted: true
        text: root.accepting ? "Keep the offering device selected to accept this invitation."
            : (root.controller.draft.deviceIds || []).length ? "Selected peers receive a sharing offer; they must accept it."
            : "Local only: no remote device will receive this folder until you choose one."
    }
    NativeText {
        objectName: "folder-validation"
        style: root.style
        Layout.fillWidth: true
        text: root.controller.validation
        visible: text !== ""
        tone: "warning"
    }
    BusyButton {
        objectName: "save-folder"
        style: root.style
        text: root.accepting ? "Accept folder" : "Add folder"
        busy: root.controller.pending
        busyText: "Adding folder"
        enabled: !root.controller.validation && root.service.online && !root.controller.blocked
        onClicked: root.controller.save()
    }
    Connections {
        target: root.controller
        function onFocusRequested(key) {
            if (key === "first-field") path.focusControl();
        }
    }
    Component.onCompleted: Qt.callLater(path.focusControl)
}
