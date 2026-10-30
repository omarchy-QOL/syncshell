pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "."
import "../models/PanelModel.js" as Model

// Omarchy's More: the Syncthing status word, errors per affected folder and
// the installation row. The footer's refresh rechecks errors, so there is no
// separate recheck button.
ColumnLayout {
    id: root
    required property var controller
    readonly property var service: controller.service
    readonly property var problemFolders: service.folders.filter(folder => Model.hasErrors(folder))
    readonly property string statusWord: problemFolders.length > 0 ? "errors" : controller.fresh ? "clean" : "unavailable"
    readonly property var installation: service.installation || ({})
    readonly property color dim: Colours.palette.m3onSurfaceVariant
    spacing: Tokens.spacing.small
    component Small: StyledText {
        font: Tokens.font.label.medium
        color: root.dim
        textFormat: Text.PlainText
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small
        Small {
            text: "Syncthing status"
        }
        Small {
            text: root.statusWord
            font.weight: Font.Bold
            color: Model.statusColour(Colours.palette, root.statusWord === "errors" ? "error" : root.statusWord === "clean" ? "success" : "")
        }
    }
    Small {
        Layout.fillWidth: true
        visible: !root.controller.fresh
        text: root.problemFolders.length > 0 ? "Last reported errors; current status is unavailable." : "Current Syncthing status is unavailable."
        wrapMode: Text.Wrap
    }
    Repeater {
        model: root.problemFolders
        ColumnLayout {
            id: problem
            required property var modelData
            Layout.fillWidth: true
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall
                MaterialIcon {
                    text: "folder"
                    color: root.dim
                    fontStyle: Tokens.font.label.medium
                }
                Small {
                    Layout.fillWidth: true
                    text: "affected: " + (problem.modelData.path || problem.modelData.id)
                    elide: Text.ElideLeft
                }
            }
            Small {
                Layout.fillWidth: true
                text: Model.errorDetails(problem.modelData)
                color: Colours.palette.m3error
                wrapMode: Text.Wrap
            }
        }
    }
    StyledRect {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Colours.palette.m3outlineVariant
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small
        Small {
            text: "Installation"
        }
        MaterialIcon {
            text: "info"
            color: Model.statusColour(Colours.palette, root.installation.available ? "success" : "warning")
            fontStyle: Tokens.font.label.large
            SharedWidgetToolTip {
                visible: infoHover.hovered
                text: root.installation.available ? "Existing installation found: executable" : "Syncthing executable not found"
            }
            HoverHandler {
                id: infoHover
            }
        }
        Small {
            Layout.fillWidth: true
            text: root.installation.executablePath || "—"
            color: Colours.palette.m3onSurface
            elide: Text.ElideMiddle
        }
        SharedWidgetSquareActionButton {
            icon: "help"
            help: "Open Syncthing installation\nand removal documentation"
            onClicked: Qt.openUrlExternally("https://docs.syncthing.net/intro/getting-started.html")
        }
    }
    Small {
        Layout.fillWidth: true
        visible: !root.installation.available
        text: "Install Syncthing with your distribution's package manager, then refresh."
        color: Model.statusColour(Colours.palette, "warning")
        wrapMode: Text.Wrap
    }
    Small {
        Layout.fillWidth: true
        text: root.service.lifecycle.error || ""
        visible: text !== ""
        color: Model.statusColour(Colours.palette, "warning")
        wrapMode: Text.Wrap
    }
    Small {
        Layout.fillWidth: true
        text: "Some entries are omitted by the core's display limits. Open Web UI for the full list."
        visible: Object.values(root.service.truncation).some(n => n > 0)
        wrapMode: Text.Wrap
    }
}
