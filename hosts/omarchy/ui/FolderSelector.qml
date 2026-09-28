import QtQuick
import qs.Commons

SyncshellDropdown {
    id: root

    required property var controller

    showLabel: false
    searchable: true
    rowHeight: Style.spacing.controlHeight
    value: controller.currentFolderId
    options: controller.folderOptions()
    helpText: "Select a configured folder, including unshared folders"
    onChanged: function (value) {
        controller.currentFolderId = value;
        root.value = Qt.binding(function () {
            return controller.currentFolderId;
        });
    }
    onVisibleChanged: if (!visible)
        close()
}
