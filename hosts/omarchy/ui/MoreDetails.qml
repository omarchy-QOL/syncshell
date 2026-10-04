pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Column {
    id: root

    property var controller
    property var syncthing
    property color foreground: Color.foreground
    property color dim: Qt.darker(foreground, 1.5)
    property color urgent: Color.urgent
    required property color warning
    required property color success
    property string fontFamily: Style.font.family
    property Item keyboardCursor: null
    readonly property string executablePath: syncthing ? String(syncthing.executablePath || "") : ""
    readonly property bool flatpakInstallation: executablePath.endsWith(" (Flatpak)")
    readonly property var problemFolders: {
        var rows = root.controller && root.controller.folderRows ? root.controller.folderRows : [];
        return rows.filter(function (folder) {
            return folder && folder.problem;
        });
    }
    readonly property var keyboardRows: [[installationHelp], [installButton]]

    signal actionHovered(Item action)

    function installationStatusText() {
        if (!syncthing)
            return "Unavailable";
        if (syncthing.installationState === "existing") {
            var status = flatpakInstallation ? "available" : "executable";
            return "Existing installation found: <font color=\"" + success + "\">" + status + "</font>";
        }
        if (syncthing.installationState === "incomplete") {
            return "Incomplete installation: <font color=\"" + urgent + "\">non-working</font>";
        }
        return syncthing.installationLabel || "Unavailable";
    }

    function installationStatusColor() {
        if (!syncthing)
            return dim;
        if (syncthing.installationState === "existing")
            return success;
        if (syncthing.installationState === "incomplete")
            return urgent;
        if (syncthing.installationState === "missing")
            return warning;
        return dim;
    }

    width: parent ? parent.width : implicitWidth
    spacing: Style.space(8)

    Column {
        width: parent.width
        spacing: Style.space(8)

        RowLayout {
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
                text: "SYNCTHING STATUS"
                foreground: root.foreground
                fontFamily: root.fontFamily
            }

            Text {
                text: root.problemFolders.length > 0 ? "errors" : (root.syncthing && root.syncthing.online && root.syncthing.statusFresh ? "clean" : "unavailable")
                textFormat: Text.PlainText
                color: root.problemFolders.length > 0 ? root.urgent : (text === "clean" ? root.success : root.dim)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
            }

            Item {
                Layout.fillWidth: true
            }
        }

        Text {
            visible: root.syncthing && !root.syncthing.statusFresh
            width: parent.width
            text: root.problemFolders.length > 0 ? "Last reported errors; current status is unavailable." : "Current Syncthing status is unavailable."
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
        }

        Repeater {
            model: root.problemFolders

            delegate: Column {
                required property var modelData
                required property int index
                readonly property int shownErrorCount: (modelData.errorDetails || []).length
                readonly property int totalErrorCount: Math.max(shownErrorCount, Number(modelData.errorCount || 0))
                width: root.width
                spacing: Style.space(4)

                Text {
                    visible: parent.modelData.path !== ""
                    width: parent.width
                    text: "\uf07b  affected: " + String(parent.modelData.path || "")
                    textFormat: Text.PlainText
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideMiddle
                }

                Text {
                    width: parent.width
                    text: root.controller.folderErrorText(parent.modelData)
                    textFormat: Text.PlainText
                    color: root.urgent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.Wrap
                }

                Text {
                    visible: parent.totalErrorCount > 0
                    width: parent.width
                    text: parent.shownErrorCount < parent.totalErrorCount ? "Showing " + parent.shownErrorCount + " of " + parent.totalErrorCount + " current errors. Open Web UI for the full list." : "Showing " + parent.shownErrorCount + " current error" + (parent.shownErrorCount === 1 ? "." : "s.")
                    textFormat: Text.PlainText
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.Wrap
                }

                PanelSeparator {
                    visible: parent.index < root.problemFolders.length - 1
                    width: parent.width
                    foreground: root.foreground
                }
            }
        }
    }

    RowLayout {
        width: parent.width
        spacing: Style.space(6)

        PanelSectionHeader {
            text: "INSTALLATION"
            foreground: root.foreground
            fontFamily: root.fontFamily
        }

        Text {
            text: "󰋽"
            textFormat: Text.PlainText
            color: root.installationStatusColor()
            font.family: root.fontFamily
            font.pixelSize: Style.font.icon

            HoverHandler {
                id: installationStatusHover
            }
            SyncshellToolTip {
                visible: installationStatusHover.hovered
                text: root.installationStatusText()
                textFormat: Text.StyledText
                fontFamily: root.fontFamily
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.executablePath || "—"
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideLeft
            wrapMode: Text.NoWrap

            HoverHandler {
                id: executablePathHover
            }
            SyncshellToolTip {
                visible: executablePathHover.hovered && root.executablePath !== ""
                text: root.executablePath
                fontFamily: root.fontFamily
            }
        }

        TooltipButton {
            id: installationHelp
            Layout.preferredWidth: Style.spacing.controlHeight
            Layout.preferredHeight: Style.spacing.controlHeight
            iconText: "\uf128"
            helpText: "Open Syncthing installation\n" + "and removal documentation"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconSize: Style.font.body
            horizontalPadding: Style.space(5)
            verticalPadding: Style.space(3)
            bordered: true
            focusable: true
            hasCursor: root.keyboardCursor === installationHelp
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(installationHelp);
            }
            onClicked: root.controller.openSyncthingPackageDocumentation()
        }
    }

    Text {
        visible: text !== ""
        width: parent.width
        text: {
            if (!root.syncthing)
                return "Installation status unavailable.";
            if (root.syncthing.installationState === "existing")
                return "";
            if (root.syncthing.installationState === "incomplete") {
                return "Repair or remove the incomplete installation manually.";
            }
            if (root.syncthing.installationState === "missing") {
                return "Installs through Omarchy. Removal is manual.";
            }
            return "Checking installation.";
        }
        textFormat: Text.PlainText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }

    Text {
        visible: root.syncthing && root.syncthing.packageStatus !== ""
        width: parent.width
        text: root.syncthing ? root.syncthing.packageStatus : ""
        textFormat: Text.PlainText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }

    Button {
        id: installButton
        visible: root.syncthing && root.syncthing.canInstall
        text: "Install Syncthing"
        tooltipText: "Exact command run: omarchy pkg add syncthing"
        bordered: true
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: root.syncthing && root.syncthing.canInstall
        hasCursor: root.keyboardCursor === installButton
        onHovered: function (hovered) {
            if (hovered)
                root.actionHovered(installButton);
        }
        onClicked: root.controller.installationAction()
    }
}
