pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

Column {
    id: root

    property var controller
    property var syncthing
    property color foreground: Color.foreground
    property color dim: Qt.darker(foreground, 1.5)
    property color urgent: Color.urgent
    required property color warning
    required property color success
    required property color syncColor
    property string fontFamily: Style.font.family
    property Item keyboardCursor: null
    readonly property bool popupOpen: folderSelector.popupOpen
    readonly property var keyboardRows: {
        var rows = folderSelector.visible ? [[folderSelector]] : [];
        for (var i = 0; i < folderCards.count; i++) {
            var card = folderCards.itemAt(i) as FolderCard;
            if (card)
                rows = rows.concat(card.keyboardRows);
        }
        return rows;
    }

    signal actionHovered(Item action)

    function closePopups() {
        folderSelector.close();
    }

    width: parent ? parent.width : implicitWidth
    spacing: Style.space(8)

    FolderSelector {
        id: folderSelector
        visible: root.controller.compactFolders
        width: parent.width
        controller: root.controller
        foreground: root.foreground
        fontFamily: root.fontFamily
        hasCursor: root.keyboardCursor === folderSelector
        onHovered: function (hovered) {
            if (hovered)
                root.actionHovered(folderSelector);
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
}
