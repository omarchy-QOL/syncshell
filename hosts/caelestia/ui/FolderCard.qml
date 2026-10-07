pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import "."
import "../models/PanelModel.js" as Model
import "../../../shared/Paths.js" as Paths

ColumnLayout {
    id: root
    required property var controller
    readonly property var folder: controller.folder
    StyledText {
        Layout.fillWidth: true
        text: root.folder ? Model.label(root.folder) : "No folder selected"
        wrapMode: Text.Wrap
    }
    StyledText {
        Layout.fillWidth: true
        text: root.folder?.path || ""
        wrapMode: Text.Wrap
    }
    StyledText {
        Layout.fillWidth: true
        text: root.folder ? Model.folderState(root.folder, root.controller.fresh).toUpperCase() : ""
    }
    StyledText {
        Layout.fillWidth: true
        visible: !!root.folder
        text: Model.bytes(root.folder?.status.globalBytes) + " in " + (root.folder?.status.globalFiles || 0) + " files; " + (root.folder?.status.needTotalItems || 0) + " remaining"
        wrapMode: Text.Wrap
    }
    Flow {
        Layout.fillWidth: true
        spacing: 6
        BusyButton {
            caption: "Open"
            disabled: !root.folder
            onClicked: Qt.openUrlExternally(Model.fileUrl(Paths.resolveFolderPath(root.folder.path, root.controller.service.homePath)))
        }
        BusyButton {
            caption: "Copy ID"
            disabled: !root.folder
            onClicked: Quickshell.clipboardText = root.folder.id
        }
        BusyButton {
            caption: "Rescan"
            disabled: !root.folder || !root.controller.fresh || root.controller.busy
            onClicked: root.controller.service.rescanFolder(root.folder.id)
        }
        BusyButton {
            caption: "Forget"
            disabled: !root.folder || !root.controller.fresh || root.controller.busy
            onClicked: root.controller.confirm("folder.forget", {
                folderId: root.folder.id
            }, "Forget folder?", Model.label(root.folder) + "\nDirectory contents are kept.")
        }
    }
    StyledText {
        Layout.fillWidth: true
        text: Model.errorDetails(root.folder)
        visible: !!text
        wrapMode: Text.Wrap
    }
    StyledText {
        Layout.fillWidth: true
        text: root.controller.service.activityText
        visible: !!text
        wrapMode: Text.Wrap
    }
}
