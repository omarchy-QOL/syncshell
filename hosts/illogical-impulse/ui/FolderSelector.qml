import QtQuick

SyncshellDropdown {
    id: root
    selectorKey: "folder"
    options: controller.folderRows
    selectedId: controller.folderId
    label: controller.folder ? controller.folder.label || controller.folder.path : "Choose folder"
    help: "Select a configured folder, including local-only folders"
    onChosen: id => controller.folderId = id
    headerAccessory: Component {
        BusyButton {
            objectName: "folder-view-options"
            style: root.style
            text: "View"
            selected: root.controller.viewOptionsOpen || root.controller.groups.length !== 5 || root.controller.sort !== "name"
            help: "Filter folder states and change sorting"
            onClicked: root.controller.viewOptionsOpen = !root.controller.viewOptionsOpen
        }
    }
    optionsContent: Component { FolderViewOptions { style: root.style; controller: root.controller } }
}
