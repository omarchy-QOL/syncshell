pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "UiConstants.js" as UiConstants
import "../models/PanelNavigation.js" as PanelNavigation

KeyboardPanel {
    id: root

    property var controller
    property alias addPathText: folderOverview.addPathText
    property alias addLabelText: folderOverview.addLabelText
    property alias addIdText: folderOverview.addIdText
    property alias selectedDeviceIds: folderOverview.selectedDeviceIds
    property alias pendingFolderValue: folderOverview.pendingFolderValue
    property string activeSection: "folders"
    property Timer refreshFeedbackTimer: Timer {
        interval: UiConstants.REFRESH_FEEDBACK_MIN_MS
    }
    property bool cursorActive: false
    property var cursorAction: null
    property int sectionCursorIndex: 0
    readonly property var controlRows: {
        var rows = [[sectionTabs]];
        rows = rows.concat(activeSection === "devices" ? remoteDevices.keyboardRows : folderOverview.keyboardRows);
        rows.push([moreButton]);
        rows = rows.concat(moreDetails.keyboardRows);
        rows.push([webUiButton]);
        rows.push([rescanAllButton, refreshStatusButton, settingsButton]);
        return rows;
    }

    function resetKeyboardCursor() {
        cursorActive = false;
        cursorAction = null;
        sectionCursorIndex = activeSection === "devices" ? 1 : 0;
    }

    function ensureKeyboardCursor() {
        if (!cursorActive)
            return;
        if (!PanelNavigation.isAvailable(cursorAction, keyCatcher))
            cursorAction = PanelNavigation.first(controlRows, keyCatcher);
        if (!cursorAction)
            cursorActive = false;
    }

    function selectKeyboardAction(action) {
        if (!PanelNavigation.isAvailable(action, keyCatcher))
            return;
        cursorActive = true;
        cursorAction = action;
        scrollActionIntoView(action);
    }

    function moveKeyboardCursor(dx, dy) {
        if (cursorActive && cursorAction === sectionTabs && dx !== 0) {
            selectSection(dx > 0 ? "devices" : "folders");
            return;
        }
        if (!cursorActive) {
            cursorActive = true;
            cursorAction = PanelNavigation.first(controlRows, keyCatcher);
        } else
            cursorAction = PanelNavigation.move(controlRows, cursorAction, dx, dy, keyCatcher);
        if (!cursorAction)
            cursorActive = false;
        else
            scrollActionIntoView(cursorAction);
    }

    function activateKeyboardAction() {
        ensureKeyboardCursor();
        var action = cursorAction;
        if (!action)
            return;
        if (typeof action.activate === "function")
            action.activate();
        else if (typeof action.toggle === "function")
            action.toggle();
        else if (typeof action.clicked === "function")
            action.clicked();
    }

    function scrollActionIntoView(action) {
        if (!PanelNavigation.contains(action, content))
            return;
        Qt.callLater(function () {
            if (!action || !PanelNavigation.contains(action, content))
                return;
            var point = action.mapToItem(panelFlick.contentItem, 0, 0);
            var top = point.y;
            var bottom = top + action.height;
            var margin = Style.space(6);
            var maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height);
            if (top < panelFlick.contentY + margin)
                panelFlick.contentY = Math.max(0, top - margin);
            else if (bottom > panelFlick.contentY + panelFlick.height - margin)
                panelFlick.contentY = Math.min(maxY, bottom + margin - panelFlick.height);
        });
    }

    function resetAddForm() {
        folderOverview.resetAddForm();
    }

    function closeTransientPopups() {
        folderOverview.closePopups();
        remoteDevices.closePopups();
        moreDetails.closePopups();
    }

    function selectSection(section) {
        sectionCursorIndex = section === "devices" ? 1 : 0;
        if (section === activeSection)
            return;
        closeTransientPopups();
        activeSection = section;
        panelFlick.contentY = 0;
    }

    function focusAddPath() {
        folderOverview.focusAddPath();
    }

    function focusPanel() {
        keyCatcher.forceActiveFocus();
    }

    function scrollToMore() {
        moreDetails.forceLayout();
        content.forceLayout();
        panelFlick.contentY = Math.max(0, Math.min(moreButton.y, panelFlick.contentHeight - panelFlick.height));
    }

    function scrollToTop() {
        panelFlick.contentY = 0;
    }

    focusTarget: keyCatcher
    contentWidth: fittedContentWidth(Style.space(400))
    contentHeight: root.controller.settingsMigrationOpen ? fittedContentHeight(Style.space(520), Style.space(560)) : fittedContentHeight(content.implicitHeight + fixedActions.height + shortcutHint.implicitHeight + Style.space(fixedActions.visible ? 24 : 12), Style.space(root.controller.moreOpen && root.controller.currentFolderRow && root.controller.currentFolderRow.problem ? 760 : 560))

    PanelKeyCatcher {
        id: keyCatcher
        anchors.fill: parent
        blocked: !root.controller.folderConfirmOpen && (root.controller.addOpen || folderOverview.popupOpen || folderOverview.childPopupOpen || remoteDevices.popupOpen || moreDetails.pendingPopupOpen)
        onCloseRequested: {
            if (root.controller.settingsMigrationOpen) {
                root.controller.chooseSettingsPort(2);
            } else if (root.controller.serviceStateDialogOpen) {
                root.controller.close();
            } else if (root.controller.removalConfirmOpen) {
                root.controller.removalConfirmOpen = false;
            } else if (root.controller.settingsMenuOpen) {
                root.controller.closeSettingsMenu();
            } else if (root.controller.folderConfirmOpen) {
                root.controller.cancelFolderAction();
            } else if (root.controller.deviceConfirmOpen) {
                root.controller.cancelDeviceAction();
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
            } else if (root.controller.folderConfirmOpen) {
                folderConfirmDialog.selectedIndex = folderConfirmDialog.selectedIndex === 0 ? 1 : 0;
            } else if (root.controller.deviceConfirmOpen) {
                deviceConfirmDialog.selectedIndex = deviceConfirmDialog.selectedIndex === 0 ? 1 : 0;
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
            } else if (root.controller.folderConfirmOpen && (dx !== 0 || dy !== 0)) {
                folderConfirmDialog.selectedIndex = folderConfirmDialog.selectedIndex === 0 ? 1 : 0;
            } else if (root.controller.deviceConfirmOpen && (dx !== 0 || dy !== 0)) {
                deviceConfirmDialog.selectedIndex = deviceConfirmDialog.selectedIndex === 0 ? 1 : 0;
            } else if (!root.controller.addOpen && (dx !== 0 || dy !== 0)) {
                root.moveKeyboardCursor(dx, dy);
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
            } else if (root.controller.folderConfirmOpen) {
                if (folderConfirmDialog.selectedIndex === 0)
                    root.controller.confirmFolderAction();
                else
                    root.controller.cancelFolderAction();
            } else if (root.controller.deviceConfirmOpen) {
                if (deviceConfirmDialog.selectedIndex === 0)
                    root.controller.confirmDeviceAction();
                else
                    root.controller.cancelDeviceAction();
            } else
                root.activateKeyboardAction();
        }
        onTextKey: function (text) {
            var key = text.toLowerCase();
            if (root.controller.settingsMigrationOpen) {
                if (key === "q")
                    root.controller.chooseSettingsPort(2);
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
            if (root.controller.folderConfirmOpen)
                return;
            if (root.controller.deviceConfirmOpen)
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

    // Side cards meet the panel border, outside its content padding.
    Item {
        id: sideCardAnchor
        parent: keyCatcher
        x: -root.padding - Border.left(root.borderSpec)
        width: keyCatcher.width
    }

    Flickable {
        id: panelFlick
        parent: keyCatcher
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: interactive ? scrollBar.implicitWidth + Style.spacing.sm : 0
        anchors.bottom: fixedActions.top
        anchors.bottomMargin: Style.space(12)
        anchors.left: parent.left
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        onMovementStarted: root.closeTransientPopups()
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

                ButtonGroup {
                    id: sectionTabs
                    options: [
                        { value: "folders", label: "FOLDERS (" + root.controller.folderRows.length + ")" },
                        { value: "devices", label: "DEVICES (" + remoteDevices.remoteRows.length + ")" }
                    ]
                    value: root.activeSection
                    foreground: root.controller.foreground
                    background: "transparent"
                    fontFamily: root.controller.fontFamily
                    fontSize: Style.font.caption
                    focusable: false
                    cursorIndex: root.cursorActive && root.cursorAction === sectionTabs ? root.sectionCursorIndex : -1
                    onChanged: function (value) {
                        root.selectSection(value);
                    }
                    onHovered: function (index, hovered) {
                        if (hovered) {
                            root.sectionCursorIndex = index;
                            root.selectKeyboardAction(sectionTabs);
                        }
                    }
                }

                FolderOverview {
                    id: folderOverview
                    visible: root.activeSection === "folders"
                    cardAnchor: sideCardAnchor
                    controller: root.controller
                    syncthing: root.controller.syncthing
                    foreground: root.controller.foreground
                    dim: root.controller.dim
                    urgent: root.controller.urgent
                    warning: root.controller.warning
                    success: root.controller.success
                    syncColor: root.controller.syncActivityColor
                    fontFamily: root.controller.fontFamily
                    keyboardCursor: root.cursorActive ? root.cursorAction : null
                    onActionHovered: function (action) {
                        root.selectKeyboardAction(action);
                    }
                }

                RemoteDevices {
                    id: remoteDevices
                    visible: root.activeSection === "devices"
                    cardAnchor: sideCardAnchor
                    width: parent.width
                    controller: root.controller
                    syncthing: root.controller.syncthing
                    foreground: root.controller.foreground
                    dim: root.controller.dim
                    urgent: root.controller.urgent
                    warning: root.controller.warning
                    success: root.controller.success
                    fontFamily: root.controller.fontFamily
                    keyboardCursor: root.cursorActive ? root.cursorAction : null
                    onActionHovered: function (action) {
                        root.selectKeyboardAction(action);
                    }
                }
            }

            Button {
                id: moreButton
                visible: !root.controller.settingsMenuOpen
                width: parent.width
                text: root.controller.moreOpen ? "Less" : "More"
                iconText: root.controller.moreOpen ? "\uf077" : "\uf078"
                leftAlign: true
                hasCursor: root.cursorActive && root.cursorAction === moreButton
                foreground: root.controller.foreground
                fontFamily: root.controller.fontFamily
                onHovered: function (hovered) {
                    if (hovered)
                        root.selectKeyboardAction(moreButton);
                }
                onClicked: root.controller.moreOpen = !root.controller.moreOpen
            }

            MoreDetails {
                id: moreDetails
                folderActions: folderOverview
                visible: !root.controller.settingsMenuOpen && root.controller.moreOpen
                controller: root.controller
                syncthing: root.controller.syncthing
                foreground: root.controller.foreground
                dim: root.controller.dim
                urgent: root.controller.urgent
                warning: root.controller.warning
                success: root.controller.success
                fontFamily: root.controller.fontFamily
                keyboardCursor: root.cursorActive ? root.cursorAction : null
                onActionHovered: function (action) {
                    root.selectKeyboardAction(action);
                }
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
                id: webUiButton
                text: "Web UI"
                height: Style.spacing.controlHeight
                bordered: true
                foreground: root.controller.foreground
                fontFamily: root.controller.fontFamily
                fontSize: Style.font.body
                horizontalPadding: Style.space(6)
                verticalPadding: Style.space(4)
                enabled: root.controller.syncthing !== null && root.controller.syncthing.online
                hasCursor: root.cursorActive && root.cursorAction === webUiButton
                onHovered: function (hovered) {
                    if (hovered)
                        root.selectKeyboardAction(webUiButton);
                }
                onClicked: root.controller.openWebUi()
            }

            Repeater {
                model: ["TUI", "GUI"]

                BusyButton {
                    required property string modelData
                    text: modelData
                    height: Style.spacing.controlHeight
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
                height: Style.spacing.controlHeight
                iconText: "󰑐"
                text: "Rescan all folders"
                busyText: "Rescanning..."
                tooltipText: "Rescan all folders for local changes."
                busy: root.controller.syncthing && root.controller.syncthing.folderMutationAction === "rescan-all"
                bordered: true
                foreground: root.controller.foreground
                busyForeground: root.controller.warning
                fontFamily: root.controller.fontFamily
                fontSize: Style.font.body
                iconSize: Style.font.body
                horizontalPadding: Style.space(5)
                verticalPadding: Style.space(4)
                canActivate: root.controller.syncthing && root.controller.syncthing.online && root.controller.rescannableFolderCount > 0 && !root.controller.syncthing.refreshing && !root.controller.syncthing.folderMutationBusy
                hasCursor: root.cursorActive && root.cursorAction === rescanAllButton
                onHovered: function (hovered) {
                    if (hovered)
                        root.selectKeyboardAction(rescanAllButton);
                }
                onClicked: root.controller.syncthing.rescanAllFolders()
            }

            BusyButton {
                id: refreshStatusButton
                property bool refreshRequested: false

                iconText: "\uf21e"
                height: Style.spacing.controlHeight
                text: "Refresh Sync.status"
                busyText: "Rechecking Syncthing"
                pulseBusyIcon: true
                tooltipText: "Request latest Syncthing state.\n" + "Active folders with current errors\n" + "rescanned and errors rechecked."
                bordered: true
                foreground: root.controller.foreground
                busyForeground: root.controller.warning
                fontFamily: root.controller.fontFamily
                fontSize: Style.font.body
                iconSize: Style.font.body
                horizontalPadding: Style.space(5)
                verticalPadding: Style.space(4)
                busy: refreshRequested || root.refreshFeedbackTimer.running
                canActivate: root.controller.syncthing && root.controller.syncthing.canRefresh && !root.refreshFeedbackTimer.running
                hasCursor: root.cursorActive && root.cursorAction === refreshStatusButton
                onHovered: function (hovered) {
                    if (hovered)
                        root.selectKeyboardAction(refreshStatusButton);
                }
                onClicked: {
                    refreshRequested = root.controller.syncthing.refresh(true);
                    if (refreshRequested)
                        root.refreshFeedbackTimer.restart();
                }

                Connections {
                    target: root.controller.syncthing
                    function onRefreshingChanged() {
                        if (!root.controller.syncthing.refreshing)
                            refreshStatusButton.refreshRequested = false;
                    }
                }
            }

            TooltipButton {
                id: settingsButton
                width: Style.spacing.controlHeight
                height: Style.spacing.controlHeight
                iconText: "\uf013"
                helpText: "Settings"
                bordered: true
                foreground: root.controller.foreground
                fontFamily: root.controller.fontFamily
                iconSize: Style.font.body
                enabled: root.controller.syncthing !== null
                hasCursor: root.cursorActive && root.cursorAction === settingsButton
                onHovered: function (hovered) {
                    if (hovered)
                        root.selectKeyboardAction(settingsButton);
                }
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
        text: root.controller.settingsMenuOpen || root.controller.settingsMigrationOpen ? "" : "[r]escan  [w]ebUI  [p]ause/continue  [s]ettings"
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
        busy: root.controller.syncthing ? root.controller.syncthing.serviceStateActionRunning : false
        message: root.controller.syncthing ? [root.controller.syncthing.serviceStateMessage, root.controller.syncthing.controlError, root.controller.syncthing.settingsError].filter(Boolean).join("\n\n") : ""
        choices: root.controller.syncthing ? [root.controller.syncthing.serviceStatePrimaryLabel, root.controller.syncthing.serviceStateSecondaryLabel] : []
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
        onActionRequested: function (index) {
            root.controller.chooseSettingsPort(index);
        }
    }

    CompactConfirmDialog {
        id: folderConfirmDialog
        parent: keyCatcher
        anchors.fill: parent
        opened: root.controller.folderConfirmOpen
        destructiveConfirmation: root.controller.folderConfirmAction !== "create"
        z: 10
        confirmFirst: true
        equalWidthActions: true
        message: {
            if (root.controller.folderConfirmAction === "create")
                return "Create " + root.controller.folderCreationArgs.path + " and add the folder?";
            var folder = root.controller.folderById(root.controller.folderConfirmId);
            if (!folder)
                return "Change this folder?";
            if (root.controller.folderConfirmAction === "link")
                return "Link " + folder.label + " (" + folder.id + ")?\n\nSyncthing will resume synchronization for this folder.";
            if (root.controller.folderConfirmAction === "unlink")
                return "Unlink " + folder.label + " (" + folder.id + ")?\n\nSyncthing will pause synchronization. Its configuration " + "and local files remain.";
            return "Forget " + folder.label + " (" + folder.id + ")?\n\n" + "This removes only its Syncthing configuration. The " + "directory and data files will not be deleted. " + (folder.markerName === ".stfolder" ? "Syncthing will also attempt to remove its internal " + ".stfolder marker. " : "") + "Rejoining the same remote folder requires this exact " + "Folder ID.";
        }
        confirmText: root.controller.folderConfirmAction === "create" ? "Create and add" : "Yes"
        cancelText: root.controller.folderConfirmAction === "create" ? "Cancel" : "No"
        background: Color.popups.background
        foreground: Color.popups.text
        selectedText: root.controller.folderConfirmAction === "create" ? root.controller.foreground : root.controller.urgent
        fontFamily: root.controller.fontFamily
        onCanceled: root.controller.cancelFolderAction()
        onConfirmed: root.controller.confirmFolderAction()
    }

    CompactConfirmDialog {
        id: deviceConfirmDialog
        implicitWidth: Style.space(root.controller.deviceConfirmAction === "remove" ? 320 : 390)
        parent: keyCatcher
        anchors.fill: parent
        opened: root.controller.deviceConfirmOpen
        z: 10
        confirmFirst: true
        equalWidthActions: true
        message: root.controller.deviceConfirmAction === "dismiss" ? "Dismiss pending request from " + root.controller.deviceConfirmName + "?\n\n" + "It can reappear if the device connects again." : "Remove " + root.controller.deviceConfirmName + " from this device?\n\nFolder sharing with it will be " + "removed locally. Local folders and files remain.\n" + "The other device is unchanged."
        confirmText: "Yes"
        cancelText: "No"
        background: Color.popups.background
        foreground: Color.popups.text
        selectedText: root.controller.urgent
        fontFamily: root.controller.fontFamily
        onCanceled: root.controller.cancelDeviceAction()
        onConfirmed: root.controller.confirmDeviceAction()
    }

    SelfRemovalDialog {
        id: removalDialog
        parent: keyCatcher
        anchors.fill: parent
        opened: root.controller.removalConfirmOpen
        busy: root.controller.syncthing ? root.controller.syncthing.settingsBusy : false
        error: root.controller.syncthing ? root.controller.syncthing.settingsError : ""
        fontFamily: root.controller.fontFamily
        z: 11
        onCanceled: root.controller.removalConfirmOpen = false
        onRemoveRequested: function (deletePluginSettings) {
            root.controller.requestSelfRemoval(deletePluginSettings);
        }
    }
}
