pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Column {
    id: root

    property var controller
    required property Item cardAnchor
    property Item addTrigger: addFolderButton
    property var syncthing: null
    property color foreground: Color.foreground
    property color dim: Qt.darker(foreground, 1.5)
    property color urgent: Color.urgent
    required property color warning
    required property color success
    required property color syncColor
    property string fontFamily: Style.font.family
    property Item keyboardCursor: null
    property alias addPathText: addForm.pathText
    property alias addLabelText: addForm.labelText
    property alias addIdText: addForm.idText
    property alias selectedDeviceIds: addForm.selectedDeviceIds
    property alias pendingFolderValue: addForm.pendingFolderValue
    readonly property bool popupOpen: folderSelector.popupOpen || pendingOfferSelector.popupOpen
    readonly property bool childPopupOpen: folderSharingForm.popupOpen
    readonly property var keyboardRows: {
        var rows = [[folderSelector, addFolderButton, shareFolderButton, linkFolderButton]];
        for (var i = 0; i < folderCards.count; i++) {
            var card = folderCards.itemAt(i) as FolderCard;
            if (card)
                rows = rows.concat(card.keyboardRows);
        }
        if (pendingOfferSelector.visible)
            rows.push([pendingOfferSelector, acceptFolderButton, rejectFolderButton]);
        return rows;
    }

    signal actionHovered(Item action)

    function closePopups() {
        folderSelector.close();
        pendingOfferSelector.close();
        addForm.closePopups();
        folderSharingForm.closePopups();
    }

    function resetAddForm() {
        addForm.reset();
    }

    function focusAddPath() {
        addForm.focusPath();
    }

    width: parent ? parent.width : implicitWidth
    spacing: Style.space(8)

    RowLayout {
        width: parent.width
        spacing: Style.space(6)

        FolderSelector {
            id: folderSelector
            visible: root.controller.folderRows.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Style.spacing.controlHeight
            controller: root.controller
            foreground: root.foreground
            fontFamily: root.fontFamily
            hasCursor: root.keyboardCursor === folderSelector
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(folderSelector);
            }
        }

        Item {
            visible: !folderSelector.visible
            Layout.fillWidth: true
        }

        SquareActionButton {
            id: addFolderButton
            glyph: "\uf067"
            helpText: "Add folder (locally)"
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: root.syncthing && root.syncthing.online && !root.syncthing.folderMutationBusy
            hasCursor: root.keyboardCursor === addFolderButton
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(addFolderButton);
            }
            onClicked: {
                root.addTrigger = addFolderButton;
                root.controller.addOpen ? root.controller.closeAddFolder() : root.controller.openAddFolder();
            }
        }

        SquareActionButton {
            id: shareFolderButton
            visible: root.controller.folderRows.length > 0
            glyph: "\uf1e0"
            helpText: "Share folder\n(other device)"
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: root.syncthing && root.syncthing.online && !root.syncthing.folderMutationBusy
            hasCursor: root.keyboardCursor === shareFolderButton
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(shareFolderButton);
            }
            onClicked: root.controller.toggleFolderSharing()
        }

        SquareActionButton {
            id: linkFolderButton
            readonly property var targetFolder: root.controller.currentFolder()
            readonly property bool mutationBusy: root.syncthing && root.syncthing.folderMutationBusy
            readonly property bool targetBusy: mutationBusy && root.syncthing.folderMutationId === root.controller.currentFolderId && (root.syncthing.folderMutationAction === "link" || root.syncthing.folderMutationAction === "unlink")
            visible: root.controller.folderRows.length > 0
            glyph: targetFolder && targetFolder.paused ? "\uf0c1" : "\uf00d"
            busy: targetBusy
            helpText: targetFolder ? (targetFolder.paused ? "Link folder" : "Unlink folder (locally)") : "Select a folder"
            foreground: targetFolder && targetFolder.paused ? root.success : root.urgent
            disabledForeground: root.dim
            fontFamily: root.fontFamily
            canActivate: targetFolder && root.syncthing && root.syncthing.online && !root.syncthing.folderMutationBusy
            hasCursor: root.keyboardCursor === linkFolderButton
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(linkFolderButton);
            }
            onClicked: root.controller.requestFolderLinkChange(targetFolder, targetFolder.paused)
        }
    }

    SideCardMenu {
        panel: root.cardAnchor
        trigger: root.addTrigger
        shown: root.controller.addOpen && root.visible && root.controller.opened
        onClosed: {
            if (!root.controller.preserveStateForFolderPicker) {
                root.controller.closeAddFolder();
                if (!root.controller.addOpen)
                    addForm.reset();
            }
        }

        contentItem: AddFolderForm {
            id: addForm
            controller: root.controller
            syncthing: root.syncthing
            folderPickerRunning: root.controller.folderPickerRunning
            foreground: root.foreground
            dim: root.dim
            urgent: root.urgent
            warning: root.controller.warning
            fontFamily: root.fontFamily
        }
    }

    SideCardMenu {
        panel: root.cardAnchor
        trigger: shareFolderButton
        shown: root.controller.folderShareOpen && root.visible && root.controller.opened
        onOpened: folderSharingForm.resetDraft()
        onClosed: {
            root.controller.folderShareOpen = false;
            folderSharingForm.resetDraft();
        }

        contentItem: FolderSharingForm {
            id: folderSharingForm
            controller: root.controller
            syncthing: root.syncthing
            foreground: root.foreground
            urgent: root.urgent
            warning: root.controller.warning
            fontFamily: root.fontFamily
        }
    }

    Text {
        visible: root.controller.folderRows.length === 0
        width: parent.width
        text: root.syncthing && root.syncthing.online ? "No folders configured." : "Folder status is unavailable."
        textFormat: Text.PlainText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignHCenter
    }

    Column {
        width: parent.width
        spacing: Style.space(6)

        Repeater {
            id: folderCards
            model: root.controller.visibleFolderRows

            FolderCard {
                required property var modelData
                width: parent.width
                folder: modelData
                controller: root.controller
                online: root.syncthing ? root.syncthing.online : false
                mutationBusy: root.syncthing ? root.syncthing.folderMutationBusy : false
                rescanning: root.controller.folderRescanning(modelData)
                stateLabel: root.controller.folderState(modelData)
                stateColor: root.controller.folderStateColor(modelData)
                meta: root.controller.folderMeta(modelData)
                activityActive: root.controller.folderHasActivity(modelData)
                activityDots: root.controller.visibleSyncDots
                activityDetail: root.controller.visibleSyncDetail
                activityAction: root.controller.visibleSyncAction
                foreground: root.foreground
                dim: root.dim
                urgent: root.urgent
                warning: root.warning
                success: root.success
                syncColor: root.syncColor
                fontFamily: root.fontFamily
                keyboardCursor: root.keyboardCursor
                onActionHovered: function (action) {
                    root.actionHovered(action);
                }
                onOpenRequested: root.controller.openFolder(modelData)
                onForgetRequested: root.controller.requestForget(modelData)
                onRescanRequested: root.syncthing.rescanFolder(modelData.id)
                onErrorDetailsRequested: function (folderId) {
                    root.controller.showFolderErrors(folderId);
                }
            }
        }
    }

    Column {
        visible: root.controller.pendingOfferRows.length > 0
        width: parent.width
        spacing: Style.space(6)

        PanelSectionHeader {
            text: "PENDING FOLDER REQUESTS"
            foreground: root.foreground
            fontFamily: root.fontFamily
        }

        RowLayout {
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
                interactive: options.length > 1
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

            SquareActionButton {
                id: acceptFolderButton
                glyph: "\uf00c"
                helpText: "Accept folder request"
                foreground: root.success
                fontFamily: root.fontFamily
                enabled: root.syncthing && root.syncthing.online && !root.syncthing.folderMutationBusy && root.controller.selectedPendingOffer !== ""
                hasCursor: root.keyboardCursor === acceptFolderButton
                onHovered: function (hovered) {
                    if (hovered)
                        root.actionHovered(acceptFolderButton);
                }
                onClicked: {
                    root.addTrigger = acceptFolderButton;
                    root.controller.acceptPendingFolderOffer(root.controller.selectedPendingOffer);
                }
            }

            SquareActionButton {
                id: rejectFolderButton
                glyph: "\uf00d"
                helpText: "Reject folder request"
                foreground: root.urgent
                fontFamily: root.fontFamily
                enabled: root.syncthing && root.syncthing.online && !root.syncthing.folderMutationBusy && root.controller.selectedPendingOffer !== ""
                hasCursor: root.keyboardCursor === rejectFolderButton
                onHovered: function (hovered) {
                    if (hovered)
                        root.actionHovered(rejectFolderButton);
                }
                onClicked: root.controller.requestPendingFolderDismiss(root.controller.selectedPendingOffer)
            }
        }
    }
}
