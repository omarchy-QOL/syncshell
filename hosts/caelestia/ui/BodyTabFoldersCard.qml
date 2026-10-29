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
    RowLayout {
        Layout.fillWidth: true
        StyledText {
            Layout.fillWidth: true
            text: root.folder ? Model.label(root.folder) : "No folder selected"
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        SharedWidgetIdCopyButton {
            visible: !!root.folder
            value: root.folder ? root.folder.id : ""
            caption: "folder ID"
            help: "Copy folder ID"
        }
    }
    StyledText {
        Layout.fillWidth: true
        text: root.folder?.path || ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    StyledText {
        Layout.fillWidth: true
        text: root.folder ? root.controller.folderStatus(root.folder) : ""
        color: Model.statusColour(Colours.palette, Model.folderStateRole(text))
    }
    StyledText {
        Layout.fillWidth: true
        visible: !!root.folder
        text: Model.folderMeta(root.folder, root.controller.fresh, root.controller.service.localDeviceId, root.controller.rescanning(root.folder))
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    Flow {
        Layout.fillWidth: true
        spacing: 6
        SharedWidgetBusyButton {
            caption: "Open"
            disabled: !root.folder
            onClicked: Qt.openUrlExternally(Model.fileUrl(Paths.resolveFolderPath(root.folder.path, root.controller.service.homePath)))
        }
        SharedWidgetBusyButton {
            caption: "Rescan"
            busyCaption: "Rescanning..."
            busy: root.controller.rescanning(root.folder)
            help: !root.controller.fresh ? "Refresh current status before rescanning" : root.folder?.paused ? "Link this folder before rescanning" : "Rescan local changes"
            disabled: !root.folder || !!root.folder.paused || !root.controller.fresh || root.controller.busy
            onClicked: root.controller.service.rescanFolder(root.folder.id)
        }
        SharedWidgetBusyButton {
            caption: "Forget"
            disabled: !root.folder || !root.controller.fresh || root.controller.busy
            onClicked: root.controller.confirm("folder.forget", {
                folderId: root.folder.id
            }, "Forget " + Model.label(root.folder) + " (" + root.folder.id + ")?", "This removes only its Syncthing configuration. The directory and data files will not be deleted. " + (root.folder.markerName === ".stfolder" ? "Syncthing will also attempt to remove its internal .stfolder marker. " : "") + "Rejoining the same remote folder requires this exact Folder ID.")
        }
    }
    StyledText {
        Layout.fillWidth: true
        text: Model.errorDetails(root.folder)
        textFormat: Text.PlainText
        visible: !!text
        wrapMode: Text.Wrap
    }
    StyledText {
        id: activityLabel
        animate: true
        SharedWidgetToolTip {
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
        textFormat: Text.PlainText
        visible: !!root.folder
        elide: Text.ElideMiddle
        maximumLineCount: 1
        color: Model.statusColour(Colours.palette, Model.activityRole(root.controller.service ? root.controller.service.currentActivity.action : ""))
    }
}
