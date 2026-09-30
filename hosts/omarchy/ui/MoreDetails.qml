import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Column {
    id: root

    property var controller
    required property var folderActions
    property var syncthing
    property color foreground: Color.foreground
    property color dim: Qt.darker(foreground, 1.5)
    property color urgent: Color.urgent
    required property color warning
    required property color success
    property string fontFamily: Style.font.family
    property Item keyboardCursor: null
    readonly property var problemFolders: {
        var rows = root.controller && root.controller.folderRows ? root.controller.folderRows : [];
        return rows.filter(function (folder) {
            return folder && folder.problem;
        });
    }
    readonly property bool pendingPopupOpen: pendingOfferSelector.popupOpen
    readonly property var keyboardRows: {
        var rows = [[pendingOfferSelector, acceptFolderButton]];
        rows.push([installationHelp]);
        rows.push([installButton]);
        return rows;
    }

    signal actionHovered(Item action)

    function closePopups() {
        if (pendingOfferSelector.popupOpen)
            pendingOfferSelector.close();
    }

    function installationStatusText() {
        if (!syncthing)
            return "Unavailable";
        if (syncthing.installationState === "existing") {
            return "Existing installation found: <font color=\"" + success + "\">working</font>";
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
                    width: parent.width
                    text: "Affected folder"
                    textFormat: Text.PlainText
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }

                Text {
                    visible: parent.modelData.path !== ""
                    width: parent.width
                    text: "\uf07b  " + String(parent.modelData.path || "")
                    textFormat: Text.PlainText
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideLeft
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

    PanelSectionHeader {
        visible: root.controller.pendingOfferRows.length > 0
        text: "PENDING FOLDER REQUESTS"
        foreground: root.foreground
        fontFamily: root.fontFamily
    }

    RowLayout {
        visible: root.controller.pendingOfferRows.length > 0
        width: parent.width
        spacing: Style.space(6)

        SyncshellDropdown {
            id: pendingOfferSelector
            Layout.fillWidth: true
            Layout.preferredHeight: Style.spacing.controlHeight
            showLabel: false
            rowHeight: Style.spacing.controlHeight
            value: root.controller.selectedPendingOffer
            options: root.controller.pendingOfferRows
            foreground: root.foreground
            fontFamily: root.fontFamily
            hasCursor: root.keyboardCursor === pendingOfferSelector
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(pendingOfferSelector);
            }
            onChanged: function (value) {
                root.controller.selectedPendingOffer = value;
                pendingOfferSelector.value = Qt.binding(function () {
                    return root.controller.selectedPendingOffer;
                });
            }
        }

        TooltipButton {
            id: acceptFolderButton
            text: "ACCEPT"
            Layout.preferredHeight: Style.spacing.controlHeight
            helpText: "Configure offered folder request"
            bordered: true
            foreground: root.success
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            horizontalPadding: Style.space(6)
            verticalPadding: Style.space(4)
            enabled: root.syncthing && root.syncthing.online && !root.syncthing.folderMutationBusy && root.controller.selectedPendingOffer !== ""
            hasCursor: root.keyboardCursor === acceptFolderButton
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(acceptFolderButton);
            }
            onClicked: {
                root.folderActions.addTrigger = acceptFolderButton;
                root.controller.acceptPendingFolderOffer(root.controller.selectedPendingOffer);
            }
        }
    }

    PanelSeparator {
        foreground: root.foreground
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

        Item {
            Layout.fillWidth: true
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

    InfoPair {
        label: "Executable"
        value: root.syncthing && root.syncthing.executablePath !== "" ? root.syncthing.executablePath : "—"
        elideMode: Text.ElideLeft
        foreground: root.foreground
        fontFamily: root.fontFamily
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
