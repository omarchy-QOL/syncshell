import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

KeyboardPanel {
    id: root

    property var controller
    property alias addPathText: addForm.pathText
    property alias addLabelText: addForm.labelText
    property alias addIdText: addForm.idText
    property alias selectedDeviceIds: addForm.selectedDeviceIds
    property alias pendingFolderValue: addForm.pendingFolderValue

    function resetAddForm() {
        addForm.reset();
    }

    function closeTransientPopups() {
        moreDetails.closePopups();
        addForm.closePopups();
    }

    function focusAddPath() {
        addForm.focusPath();
    }

    function focusPanel() {
        keyCatcher.forceActiveFocus();
    }

    function scrollToMore() {
        moreDetails.forceLayout();
        content.forceLayout();
        panelFlick.contentY = Math.max(0, Math.min(moreButton.y,
            panelFlick.contentHeight - panelFlick.height));
    }

    function scrollToTop() {
        panelFlick.contentY = 0;
    }

    focusTarget: keyCatcher
    contentWidth: fittedContentWidth(Style.space(400))
    contentHeight: root.controller.settingsMigrationOpen
        ? fittedContentHeight(Style.space(520), Style.space(560))
        : fittedContentHeight(content.implicitHeight + fixedActions.height + shortcutHint.implicitHeight + Style.space(fixedActions.visible ? 24 : 12),
        Style.space(root.controller.moreOpen
            && root.controller.selectedFolderRow
            && root.controller.selectedFolderRow.problem ? 760 : 560))

    PanelKeyCatcher {
        id: keyCatcher
        anchors.fill: parent
        blocked: root.controller.addOpen || moreDetails.folderPopupOpen || moreDetails.pendingPopupOpen
        onCloseRequested: {
            if (root.controller.settingsMigrationOpen) {
                root.controller.chooseSettingsPort(2);
            } else if (root.controller.serviceStateDialogOpen) {
                root.controller.close();
            } else if (root.controller.removalConfirmOpen) {
                root.controller.removalConfirmOpen = false;
            } else if (root.controller.settingsMenuOpen) {
                root.controller.closeSettingsMenu();
            } else if (root.controller.forgetConfirmOpen) {
                root.controller.forgetConfirmOpen = false;
                root.controller.forgetFolderId = "";
            } else if (root.controller.addOpen)
                root.controller.closeAddFolder();
            else
                root.controller.close();
        }
        onTabRequested: function (direction) {
            if (root.controller.settingsMigrationOpen) {
                migrationDialog.moveChoice(direction);
            } else if (root.controller.serviceStateDialogOpen) {
                serviceStateDialog.moveChoice(direction);
            } else if (root.controller.removalConfirmOpen) {
                removalDialog.selectedChoice = (removalDialog.selectedChoice + (direction > 0 ? 1 : 2)) % 3;
            } else if (root.controller.settingsMenuOpen) {
                root.controller.moveSettingsSelection(direction);
            } else
                root.controller.switchPanel(direction);
        }
        onMoveRequested: function (dx, dy) {
            if (root.controller.settingsMigrationOpen && (dx !== 0 || dy !== 0)) {
                migrationDialog.moveChoice(dy || dx);
            } else if (root.controller.serviceStateDialogOpen && (dx !== 0 || dy !== 0)) {
                serviceStateDialog.selectedChoice = serviceStateDialog.selectedChoice === 0 ? 1 : 0;
            } else if (root.controller.removalConfirmOpen && dy !== 0) {
                removalDialog.selectedChoice = (removalDialog.selectedChoice + (dy > 0 ? 1 : 2)) % 3;
            } else if (root.controller.settingsMenuOpen && dy !== 0) {
                root.controller.moveSettingsSelection(dy);
            } else if (root.controller.forgetConfirmOpen && (dx !== 0 || dy !== 0)) {
                forgetDialog.selectedIndex = forgetDialog.selectedIndex === 0 ? 1 : 0;
            } else if (!root.controller.addOpen && dx !== 0) {
                root.controller.selectFolderOffset(dx);
            }
        }
        onActivateRequested: {
            if (root.controller.settingsMigrationOpen) {
                migrationDialog.choose();
            } else if (root.controller.serviceStateDialogOpen) {
                serviceStateDialog.choose();
            } else if (root.controller.removalConfirmOpen) {
                removalDialog.choose();
            } else if (root.controller.settingsMenuOpen) {
                root.controller.activateSettingsSelection();
            } else if (root.controller.forgetConfirmOpen) {
                if (forgetDialog.selectedIndex === 0) {
                    root.controller.forgetConfirmOpen = false;
                    root.controller.forgetFolderId = "";
                } else
                    root.controller.confirmForget();
            }
        }
        onTextKey: function (text) {
            var key = text.toLowerCase();
            if (root.controller.settingsMigrationOpen) {
                if (key === "q") root.controller.chooseSettingsPort(2);
                return;
            }
            if (root.controller.serviceStateDialogOpen) {
                if (key === "q")
                    root.controller.close();
                return;
            }
            if (root.controller.removalConfirmOpen) {
                if (key === "q")
                    root.controller.removalConfirmOpen = false;
                return;
            }
            if (root.controller.settingsMenuOpen) {
                if (key === "q")
                    root.controller.closeSettingsMenu();
                return;
            }
            if (root.controller.forgetConfirmOpen)
                return;
            if (key === "r") {
                rescanAllButton.activate();
            } else if (key === "w")
                root.controller.openWebUi();
            else if (key === "p")
                root.controller.toggleSyncing();
            else if (key === "s")
                root.controller.openSettingsMenu();
            else if (key === "q")
                root.controller.close();
        }
    }

    Flickable {
        id: panelFlick
        parent: keyCatcher
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: interactive
            ? scrollBar.implicitWidth + Style.spacing.sm : 0
        anchors.bottom: fixedActions.top
        anchors.bottomMargin: Style.space(12)
        anchors.left: parent.left
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar {
            id: scrollBar
            parent: keyCatcher
            anchors.top: panelFlick.top
            anchors.left: panelFlick.right
            anchors.leftMargin: Style.spacing.sm
            anchors.bottom: panelFlick.bottom
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: content
            x: Style.spacing.hairline
            width: panelFlick.width - x
            spacing: Style.space(12)

            PanelStatus {
                visible: !root.controller.settingsMenuOpen
                controller: root.controller
                syncthing: root.controller.syncthing
                foreground: root.controller.foreground
                urgent: root.controller.urgent
                warning: root.controller.warning
                success: root.controller.success
                fontFamily: root.controller.fontFamily
            }

            PanelSeparator {
                visible: !root.controller.settingsMenuOpen
                foreground: root.controller.foreground
            }

            Column {
                visible: !root.controller.settingsMenuOpen
                width: parent.width
                spacing: Style.space(8)

                PanelSectionHeader {
                    text: "FOLDERS"
                    foreground: root.controller.foreground
                    fontFamily: root.controller.fontFamily
                }

                AddFolderForm {
                    id: addForm
                    visible: root.controller.addOpen
                    controller: root.controller
                    syncthing: root.controller.syncthing
                    folderPickerRunning: root.controller.folderPickerRunning
                    foreground: root.controller.foreground
                    dim: root.controller.dim
                    urgent: root.controller.urgent
                    warning: root.controller.warning
                    success: root.controller.success
                    fontFamily: root.controller.fontFamily
                }

                FolderOverview {
                    id: folderOverview
                    controller: root.controller
                    syncthing: root.controller.syncthing
                    foreground: root.controller.foreground
                    dim: root.controller.dim
                    urgent: root.controller.urgent
                    success: root.controller.success
                    syncColor: root.controller.syncthingBlue
                    fontFamily: root.controller.fontFamily
                }
            }

            Button {
                id: moreButton
                visible: !root.controller.settingsMenuOpen
                width: parent.width
                text: root.controller.moreOpen ? "Less" : "More"
                iconText: root.controller.moreOpen ? "\uf077" : "\uf078"
                leftAlign: true
                foreground: root.controller.foreground
                fontFamily: root.controller.fontFamily
                onClicked: root.controller.moreOpen = !root.controller.moreOpen
            }

            MoreDetails {
                id: moreDetails
                visible: !root.controller.settingsMenuOpen && root.controller.moreOpen
                controller: root.controller
                syncthing: root.controller.syncthing
                foreground: root.controller.foreground
                dim: root.controller.dim
                urgent: root.controller.urgent
                success: root.controller.success
                fontFamily: root.controller.fontFamily
            }

            SettingsMenu {
                visible: root.controller.settingsMenuOpen
                width: parent.width
                selectedIndex: root.controller.settingsSelectedIndex
                fontFamily: root.controller.fontFamily
                onHighlightRequested: function (index) {
                    root.controller.settingsSelectedIndex = index;
                }
                onActivated: function (index) {
                    root.controller.settingsSelectedIndex = index;
                    root.controller.activateSettingsSelection();
                }
            }
        }
    }

    Column {
        id: fixedActions
        parent: keyCatcher
        visible: !root.controller.settingsMenuOpen
        height: visible ? implicitHeight : 0
        anchors.right: parent.right
        anchors.bottom: shortcutHint.top
        anchors.bottomMargin: Style.space(12)
        anchors.left: parent.left
        spacing: Style.space(12)

        PanelSeparator {
            foreground: root.controller.foreground
        }

        Row {
            spacing: Style.space(6)

            Button {
                text: "Web UI"
                bordered: true
                foreground: root.controller.foreground
                fontFamily: root.controller.fontFamily
                fontSize: Style.font.body
                horizontalPadding: Style.space(6)
                verticalPadding: Style.space(4)
                enabled: root.controller.syncthing !== null
                    && root.controller.syncthing.online
                onClicked: root.controller.openWebUi()
            }

            Repeater {
                model: ["TUI", "GUI"]

                BusyButton {
                    required property string modelData
                    text: modelData
                    tooltipText: "To be added soon."
                    canActivate: false
                    bordered: true
                    foreground: root.controller.foreground
                    disabledForeground: root.controller.dim
                    fontFamily: root.controller.fontFamily
                    fontSize: Style.font.body
                    horizontalPadding: Style.space(6)
                    verticalPadding: Style.space(4)
                }
            }
        }

        Row {
            spacing: Style.spacing.sm

            BusyButton {
                id: rescanAllButton
                iconText: "󰑐"
                text: "Rescan all folders"
                busyText: "Rescanning..."
                busy: root.controller.syncthing
                    && root.controller.syncthing.folderMutationAction
                        === "rescan-all"
                bordered: true
                foreground: root.controller.foreground
                busyForeground: root.controller.warning
                fontFamily: root.controller.fontFamily
                fontSize: Style.font.body
                iconSize: Style.font.body
                horizontalPadding: Style.spacing.sm
                verticalPadding: Style.space(4)
                canActivate: root.controller.syncthing
                    && root.controller.syncthing.online
                    && root.controller.rescannableFolderCount > 0
                    && !root.controller.syncthing.refreshing
                    && !root.controller.syncthing.folderMutationBusy
                onClicked: root.controller.syncthing.rescanAllFolders()
            }

            BusyButton {
                iconText: "\uf21e"
                text: "Refresh Sync.status"
                busyText: "Rechecking Syncthing"
                tooltipText: "Request latest Syncthing state.\n"
                    + "Active folders with current errors\n"
                    + "rescanned and errors rechecked."
                bordered: true
                foreground: root.controller.foreground
                busyForeground: root.controller.warning
                fontFamily: root.controller.fontFamily
                fontSize: Style.font.body
                iconSize: Style.font.body
                horizontalPadding: Style.spacing.sm
                verticalPadding: Style.space(4)
                busy: root.controller.syncthing
                    && root.controller.syncthing.refreshing
                canActivate: root.controller.syncthing
                    && root.controller.syncthing.canRefresh
                onClicked: root.controller.syncthing.refresh(true)
            }

            Button {
                width: rescanAllButton.height
                height: rescanAllButton.height
                iconText: "\uf013"
                iconSize: Style.font.body
                tooltipText: "Settings"
                bordered: true
                foreground: root.controller.foreground
                fontFamily: root.controller.fontFamily
                enabled: root.controller.syncthing !== null
                onClicked: root.controller.openSettingsMenu()
            }
        }

    }

    Text {
        id: shortcutHint
        parent: keyCatcher
        z: root.controller.removalConfirmOpen ? 12 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: root.controller.settingsMenuOpen || root.controller.settingsMigrationOpen
            ? "MOVE (j/k or Up/Down)  SELECT (Enter)  BACK (q/Esc)"
            : "[r]escan all  [w]ebUI  [p]ause/continue  [s]ettings"
        textFormat: Text.PlainText
        color: root.controller.dim
        font.family: root.controller.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.8
    }

    ChoiceDialog {
        id: serviceStateDialog
        parent: keyCatcher
        anchors.fill: parent
        opened: root.controller.serviceStateDialogOpen
        busy: root.controller.syncthing
            ? root.controller.syncthing.serviceStateActionRunning : false
        message: root.controller.syncthing
            ? [root.controller.syncthing.serviceStateMessage,
               root.controller.syncthing.controlError,
               root.controller.syncthing.settingsError].filter(Boolean).join("\n\n") : ""
        choices: root.controller.syncthing
            ? [root.controller.syncthing.serviceStatePrimaryLabel,
               root.controller.syncthing.serviceStateSecondaryLabel] : []
        fontFamily: root.controller.fontFamily
        z: 12
        onActionRequested: function (index) {
            root.controller.chooseServiceStateAction(index);
        }
    }

    ChoiceDialog {
        id: migrationDialog
        parent: keyCatcher
        anchors.fill: parent
        opened: root.controller.settingsMigrationOpen
        busy: root.controller.syncthing && root.controller.syncthing.settingsBusy
        message: root.controller.syncthing ? root.controller.syncthing.settingsMigrationMessage : ""
        choices: ["Auto-port", "Manual port", "Cancel"]
        choiceEnabled: [root.controller.syncthing && root.controller.syncthing.settingsCanAutoPort, true, true]
        initialChoice: choiceEnabled[0] ? 0 : 1
        busyText: "Preparing settings..."
        fontFamily: root.controller.fontFamily
        z: 13
        onActionRequested: function(index) { root.controller.chooseSettingsPort(index); }
    }

    CompactConfirmDialog {
        id: forgetDialog
        parent: keyCatcher
        anchors.fill: parent
        opened: root.controller.forgetConfirmOpen
        z: 10
        message: {
            var folder = root.controller.selectedFolderRow;
            return folder ? "Forget " + folder.label + " (" + folder.id + ")?\n\n" + "This removes only its Syncthing configuration. The " + "directory and data files will not be deleted. " + (folder.markerName === ".stfolder" ? "Syncthing will also attempt to remove its internal " + ".stfolder marker. " : "") + "Rejoining the same remote folder requires this exact Folder ID." : "Forget this unlinked folder?";
        }
        confirmText: "Forget"
        background: Color.background
        foreground: root.controller.foreground
        selectedText: root.controller.urgent
        fontFamily: root.controller.fontFamily
        onCanceled: {
            root.controller.forgetConfirmOpen = false;
            root.controller.forgetFolderId = "";
        }
        onConfirmed: root.controller.confirmForget()
    }

    SelfRemovalDialog {
        id: removalDialog
        parent: keyCatcher
        anchors.fill: parent
        opened: root.controller.removalConfirmOpen
        busy: root.controller.syncthing ? root.controller.syncthing.settingsBusy : false
        fontFamily: root.controller.fontFamily
        z: 11
        onCanceled: root.controller.removalConfirmOpen = false
        onRemoveRequested: function (deletePluginSettings) {
            root.controller.requestSelfRemoval(deletePluginSettings);
        }
    }
}
