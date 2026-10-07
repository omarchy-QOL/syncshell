import QtQuick
import qs.Common
import qs.Widgets

SyncshellDropdown {
    id: root
    required property var controller
    property bool filtersOpen: false
    searchOwner: controller
    searchKey: "folderSearch"
    totalCount: controller.service ? controller.service.folders.length : 0
    options: controller.folderOptions
    value: controller.selectedFolderId
    placeholder: controller.folder ? controller.folder.label || controller.folder.id : "No matching folders"
    onSelected: value => controller.selectedFolderId = value
    accessory: Component {
        Column {
            width: parent.width
            spacing: Theme.spacingS
            DankButton {
                text: root.filtersOpen ? "Hide filters" : "Filter and sort"
                onClicked: root.filtersOpen = !root.filtersOpen
            }
            FolderViewOptions {
                width: parent.width
                controller: root.controller
                visible: root.filtersOpen
            }
        }
    }
}
