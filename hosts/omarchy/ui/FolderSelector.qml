pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

SyncshellDropdown {
    id: root

    required property var controller
    readonly property var currentFolder: controller.currentFolderRow

    showLabel: false
    searchable: true
    interactive: controller.folderRows.length > 1
    rowHeight: Style.spacing.controlHeight
    value: controller.currentFolderId
    displayText: currentFolder ? controller.folderDisplayLabel(controller.currentFolderId) : ""
    options: controller.folderViewOptions()
    helpText: "Select a configured folder,\nincluding unshared folders"
    searchHeaderAccessory: Component {
        FolderViewOptions {
            controller: root.controller
            resultCount: root.matchingOptions.length
            totalCount: root.controller.folderRows.length
            foreground: root.foreground
            urgent: root.controller.urgent
            fontFamily: root.fontFamily
            onClosed: root.focusResults()
        }
    }
    onChanged: function (value) {
        controller.currentFolderId = value;
        root.value = Qt.binding(function () {
            return controller.currentFolderId;
        });
    }
    onVisibleChanged: if (!visible)
        close()
}
