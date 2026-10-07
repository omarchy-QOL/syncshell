pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
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
        text: root.folder ? root.controller.folderStatus(root.folder) : ""
        color: text === "ERROR" ? Colours.palette.m3error : text === "UNKNOWN" || text === "UNLINKED" ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3primary
    }
    StyledText {
        Layout.fillWidth: true
        visible: !!root.folder
        text: Model.folderMeta(root.folder, root.controller.fresh, root.controller.service.localDeviceId, root.controller.rescanning(root.folder))
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
            copyValue: root.folder ? root.folder.id : ""
        }
        BusyButton {
            caption: "Rescan"
            busyCaption: "Rescanning..."
            busy: root.controller.rescanning(root.folder)
            help: !root.controller.fresh ? "Refresh current status before rescanning" : root.folder?.paused ? "Link this folder before rescanning" : "Rescan local changes"
            disabled: !root.folder || !!root.folder.paused || !root.controller.fresh || root.controller.busy
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
        id: activityLabel
        animate: true
        SyncshellToolTip {
            text: activityLabel.text
            visible: activityHover.hovered && !!text
        }
        HoverHandler {
            id: activityHover
        }
        Layout.fillWidth: true
        Layout.minimumHeight: activityMetrics.height
        FontMetrics {
            id: activityMetrics
            font: activityLabel.font
        }
        text: root.controller.folderActivity(root.folder)
        visible: !!root.folder
        elide: Text.ElideMiddle
        maximumLineCount: 1
        color: Colours.palette.m3primary
    }
}
