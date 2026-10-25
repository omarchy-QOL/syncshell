pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
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
    property bool cursorActive: false
    property var cursorAction: null
    property int sectionCursorIndex: 0
    readonly property var controlRows: {
        var rows = [[sectionTabs]];
        rows = rows.concat(activeSection === "devices" ? remoteDevices.keyboardRows : folderOverview.keyboardRows);
        rows.push([moreButton]);
        rows = rows.concat(moreDetails.keyboardRows);
        rows = rows.concat(fixedActions.keyboardRows);
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

    function scrollToBottom() {
        moreDetails.forceLayout();
        content.forceLayout();
        panelFlick.contentY = Math.max(0, panelFlick.contentHeight - panelFlick.height);
    }

    function scrollToTop() {
        panelFlick.contentY = 0;
    }

    focusTarget: keyCatcher
    contentWidth: fittedContentWidth(Style.space(400))
    contentHeight: root.controller.settingsMigrationOpen ? fittedContentHeight(Style.space(520), Style.space(560)) : fittedContentHeight(content.implicitHeight + fixedActions.height + shortcutHint.implicitHeight + Style.space(fixedActions.visible ? 24 : 12), root.controller.moreOpen ? (root.controller.hasProblems ? Style.space(760) : 0) : Style.space(560))

    PanelKeyCatcher {
        id: keyCatcher
        anchors.fill: parent
        blocked: !root.controller.folderConfirmOpen && (root.controller.addOpen || folderOverview.popupOpen || folderOverview.childPopupOpen || remoteDevices.popupOpen)
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
                fixedActions.activateRescanAll();
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

            Header {
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

                BodyTabFolders {
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

                BodyTabDevices {
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
                onClicked: {
                    root.controller.moreOpen = !root.controller.moreOpen;
                    if (root.controller.moreOpen)
                        Qt.callLater(root.scrollToBottom);
                }
            }

            BodyMore {
                id: moreDetails
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

    FooterActions {
        id: fixedActions
        parent: keyCatcher
        visible: !root.controller.settingsMenuOpen
        height: visible ? implicitHeight : 0
        anchors.right: parent.right
        anchors.bottom: shortcutHint.top
        anchors.bottomMargin: Style.space(12)
        anchors.left: parent.left
        controller: root.controller
        keyboardCursor: root.cursorActive ? root.cursorAction : null
        onActionHovered: function (action) {
            root.selectKeyboardAction(action);
        }
    }

    FooterShortcutHint {
        id: shortcutHint
        parent: keyCatcher
        z: root.controller.removalConfirmOpen ? 12 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        controller: root.controller
    }

    SharedDialogChoice {
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

    SharedDialogChoice {
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

    SharedDialogConfirm {
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
            if (root.controller.folderConfirmAction === "dismiss-offer")
                return "Reject folder request for " + root.controller.folderConfirmLabel + "?\n\nThis removes the pending announcement without adding the folder.";
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
        background: Commons.Color.popups.background
        foreground: Commons.Color.popups.text
        selectedText: root.controller.folderConfirmAction === "create" ? root.controller.foreground : root.controller.urgent
        fontFamily: root.controller.fontFamily
        onCanceled: root.controller.cancelFolderAction()
        onConfirmed: root.controller.confirmFolderAction()
    }

    SharedDialogConfirm {
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
        background: Commons.Color.popups.background
        foreground: Commons.Color.popups.text
        selectedText: root.controller.urgent
        fontFamily: root.controller.fontFamily
        onCanceled: root.controller.cancelDeviceAction()
        onConfirmed: root.controller.confirmDeviceAction()
    }

    SettingsSelfRemovalDialog {
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
