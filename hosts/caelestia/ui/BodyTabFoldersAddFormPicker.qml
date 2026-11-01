pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Qt.labs.folderlistmodel
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.containers
import "."
import "../models/PanelModel.js" as Model
import "../../../shared/Paths.js" as Paths

ColumnLayout {
    id: root
    property string initialPath: ""
    property string directory: Paths.resolveFolderPath(initialPath || "~", Quickshell.env("HOME")) || "/"
    signal selected(string path)
    signal cancelled
    spacing: Tokens.spacing.medium
    StyledText {
        Layout.fillWidth: true
        text: "Choose a directory"
        wrapMode: Text.Wrap
    }
    StyledTextField {
        id: path
        Layout.fillWidth: true
        text: root.directory
        placeholderText: "Absolute directory path"
        onAccepted: root.directory = Paths.resolveFolderPath(text, Quickshell.env("HOME"))
    }
    RowLayout {
        SharedWidgetBusyButton {
            caption: "Up"
            onClicked: root.directory = root.directory.replace(/\/+$/, "").replace(/\/[^/]*$/, "") || "/"
        }
        SharedWidgetBusyButton {
            caption: "Go"
            onClicked: root.directory = Paths.resolveFolderPath(path.text, Quickshell.env("HOME"))
        }
    }
    FolderListModel {
        id: directories
        folder: Model.fileUrl(root.directory)
        showFiles: false
        showDirs: true
        showDotAndDotDot: false
        showHidden: true
    }
    StyledListView {
        id: list
        Layout.fillWidth: true
        implicitHeight: 230
        clip: true
        model: directories
        spacing: Tokens.spacing.small
        QQC.ScrollBar.vertical: StyledScrollBar {
            flickable: list
        }
        delegate: SharedWidgetBusyButton {
            required property string fileName
            required property string filePath
            width: ListView.view.width
            caption: fileName
            onClicked: root.directory = filePath
        }
    }
    StyledText {
        Layout.fillWidth: true
        text: "Only directories are listed. Use Go to load a typed path."
        wrapMode: Text.Wrap
    }
    RowLayout {
        SharedWidgetBusyButton {
            caption: "Cancel"
            onClicked: root.cancelled()
        }
        SharedWidgetBusyButton {
            caption: "Choose"
            disabled: directories.status !== FolderListModel.Ready
            onClicked: root.selected(root.directory)
        }
    }
    Keys.onEscapePressed: root.cancelled()
    Component.onCompleted: path.forceActiveFocus()
}
