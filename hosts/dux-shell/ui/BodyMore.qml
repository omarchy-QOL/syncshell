import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets
import "../models/PanelModel.js" as Model

// Omarchy's More: a full-width disclosure, the Syncthing status word, errors
// per affected folder and the installation row. The footer's refresh
// rechecks errors, so there is no separate recheck button.
ColumnLayout {
    id: root
    required property var controller
    readonly property var service: controller.service
    readonly property var problemFolders: service ? service.folders.filter(folder => Model.hasErrors(folder)) : []
    readonly property string statusWord: problemFolders.length > 0 ? "errors" : root.controller.fresh ? "clean" : "unavailable"
    readonly property var installation: service ? service.installation : ({})
    spacing: Theme.spacingS
    SharedWidgetTooltipButton {
        Layout.fillWidth: true
        flat: true
        leftAlign: true
        text: root.controller.moreOpen ? "Less" : "More"
        iconName: root.controller.moreOpen ? "expand_less" : "expand_more"
        Accessible.name: root.controller.moreOpen ? "Hide details" : "Show details"
        onClicked: root.controller.moreOpen = !root.controller.moreOpen
    }
    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacingS
        Layout.rightMargin: Theme.spacingS
        visible: root.controller.moreOpen
        spacing: Theme.spacingS
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            StyledText {
                text: "Syncthing status"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.onSurfaceVariant
            }
            StyledText {
                text: root.statusWord
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                color: root.statusWord === "errors" ? Theme.error : root.statusWord === "clean" ? Theme.success : Theme.onSurfaceVariant
            }
        }
        StyledText {
            Layout.fillWidth: true
            visible: !root.controller.fresh
            text: root.problemFolders.length > 0 ? "Last reported errors; current status is unavailable." : "Current Syncthing status is unavailable."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.onSurfaceVariant
            wrapMode: Text.Wrap
        }
        Repeater {
            model: root.problemFolders
            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXS
                    DIcon {
                        name: "folder"
                        size: Theme.fontSizeSmall + 2
                        color: Theme.onSurfaceVariant
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "affected: " + (modelData.path || modelData.id)
                        textFormat: Text.PlainText
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.onSurfaceVariant
                        wrapMode: Text.NoWrap
                        elide: Text.ElideLeft
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Model.errorDetails(modelData)
                    textFormat: Text.PlainText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                    color: Theme.error
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.outlineWidth
            color: Theme.outlineVariant
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            StyledText {
                text: "Installation"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.onSurfaceVariant
            }
            DIcon {
                name: "info"
                size: Theme.fontSizeSmall + 4
                color: !root.service ? Theme.onSurfaceVariant : root.installation.available ? Theme.success : Theme.warning
                SharedWidgetToolTip {
                    anchors.fill: parent
                    text: !root.service ? "Unavailable" : root.installation.available ? "Existing installation found: executable" : "Syncthing executable not found"
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: root.installation.executablePath || "—"
                textFormat: Text.PlainText
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.NoWrap
                elide: Text.ElideMiddle
                SharedWidgetToolTip {
                    anchors.fill: parent
                    text: root.installation.executablePath || ""
                }
            }
            SharedWidgetSquareActionButton {
                iconName: "help"
                help: "Open Syncthing installation\nand removal documentation"
                onClicked: Qt.openUrlExternally("https://docs.syncthing.net/intro/getting-started.html")
            }
        }
        StyledText {
            Layout.fillWidth: true
            visible: !!root.service && !root.installation.available
            text: "Install Syncthing with your distribution's package manager, then refresh."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.warning
            wrapMode: Text.Wrap
        }
        StyledText {
            Layout.fillWidth: true
            text: root.service && root.service.lifecycle.error || ""
            visible: text !== ""
            textFormat: Text.PlainText
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.warning
            wrapMode: Text.Wrap
        }
        StyledText {
            Layout.fillWidth: true
            text: "Some entries are omitted by the core's display limits. Open Web UI for the full list."
            visible: !!root.service && Object.values(root.service.truncation).some(n => n > 0)
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.onSurfaceVariant
            wrapMode: Text.Wrap
        }
    }
}
