import QtQuick
import qs.Common
import "../models/PanelModel.js" as Model

SharedWidgetDropdown {
    id: root
    required property var controller
    property bool filtersOpen: false
    searchOwner: controller
    searchKey: "folderSearch"
    totalCount: controller.service ? controller.service.folders.length : 0
    options: controller.folderOptions
    value: controller.selectedFolderId
    placeholder: controller.folder ? Model.folderName(controller.folder) : "No matching folders"
    onSelected: value => controller.selectedFolderId = value
    accessory: Component {
        Column {
            width: parent.width
            spacing: Theme.spacingS
            SharedWidgetTooltipButton {
                iconName: "filter_list"
                text: root.filtersOpen ? "Hide filters" : "Filter and sort"
                onClicked: root.filtersOpen = !root.filtersOpen
            }
            BodyTabFoldersViewOptions {
                width: parent.width
                controller: root.controller
                visible: root.filtersOpen
            }
        }
    }
}
