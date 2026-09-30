import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Column {
    id: root

    property var controller
    required property Item cardAnchor
    required property var folderActions
    property var syncthing
    property color foreground: Color.foreground
    property color dim: Qt.darker(foreground, 1.5)
    property color urgent: Color.urgent
    required property color warning
    required property color success
    property string fontFamily: Style.font.family
    property Item keyboardCursor: null
    readonly property var currentFolder: root.controller.currentFolderRow
    readonly property int shownErrorCount: currentFolder ? (currentFolder.errorDetails || []).length : 0
    readonly property int totalErrorCount: currentFolder ? Math.max(shownErrorCount, Number(currentFolder.errorCount || 0)) : 0
    readonly property bool pendingPopupOpen: pendingOfferSelector.popupOpen
    readonly property bool childPopupOpen: remoteDevices.popupOpen
    readonly property var keyboardRows: {
        var rows = [[pendingOfferSelector, acceptFolderButton]];
        rows = rows.concat(remoteDevices.keyboardRows);
        rows.push([installationHelp]);
        rows.push([installButton]);
        return rows;
    }

    signal actionHovered(Item action)

    function closePopups() {
        if (pendingOfferSelector.popupOpen)
            pendingOfferSelector.close();
        remoteDevices.closePopups();
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
        visible: root.currentFolder && root.currentFolder.problem
        width: parent.width
        spacing: Style.space(8)

        PanelSectionHeader {
            text: "FOLDER ERRORS"
            foreground: root.foreground
            fontFamily: root.fontFamily
        }

        Text {
            width: parent.width
            text: root.currentFolder ? "\uf07b  " + (root.currentFolder.configuredLabel || root.currentFolder.label) : ""
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
        }

        Text {
            visible: root.syncthing && !root.syncthing.statusFresh
            width: parent.width
            text: "Last reported errors; current status is unavailable."
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
        }

        Text {
            width: parent.width
            text: root.controller.folderErrorText(root.currentFolder)
            textFormat: Text.PlainText
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
        }

        Text {
            width: parent.width
            text: root.shownErrorCount < root.totalErrorCount ? "Showing " + root.shownErrorCount + " of " + root.totalErrorCount + " current errors. Open Web UI for the full list." : "Showing " + root.shownErrorCount + " current error" + (root.shownErrorCount === 1 ? "." : "s.")
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
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

    RemoteDevices {
        id: remoteDevices
        cardAnchor: root.cardAnchor
        width: parent.width
        controller: root.controller
        syncthing: root.syncthing
        foreground: root.foreground
        dim: root.dim
        urgent: root.urgent
        warning: root.controller.warning
        success: root.success
        fontFamily: root.fontFamily
        keyboardCursor: root.keyboardCursor
        onActionHovered: function (action) {
            root.actionHovered(action);
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
