pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import "."

ColumnLayout {
    id: root
    required property var controller
    required property var owner
    Loader {
        active: !!root.controller.view.form
        Layout.fillWidth: true
        sourceComponent: root.controller.view.picking ? picker : root.controller.view.form === "settings" ? settings : root.controller.view.form === "add-folder" ? folder : root.controller.view.form === "share-folder" ? sharing : root.controller.view.form === "device-folders" ? deviceFolders : device
    }
    StyledText {
        Layout.fillWidth: true
        text: root.controller.error
        textFormat: Text.PlainText
        visible: !!text
        wrapMode: Text.Wrap
    }
    Component {
        id: folder
        BodyTabFoldersAddForm {
            controller: root.controller
            onBrowseRequested: root.controller.update({
                picking: true
            })
        }
    }
    Component {
        id: sharing
        BodyTabFoldersShareForm {
            controller: root.controller
        }
    }
    Component {
        id: deviceFolders
        BodyTabDevicesFoldersForm {
            controller: root.controller
        }
    }
    Component {
        id: device
        BodyTabDevicesAddForm {
            controller: root.controller
        }
    }
    Component {
        id: settings
        SettingsPage {
            controller: root.controller
            owner: root.owner
        }
    }
    Component {
        id: picker
        BodyTabFoldersAddFormPicker {
            initialPath: root.controller.view.draft.path || ""
            onSelected: path => {
                root.controller.draft({
                    path: path
                });
                root.controller.update({
                    picking: false
                });
                root.controller.restoreFocus("form");
            }
            onCancelled: {
                root.controller.update({
                    picking: false
                });
                root.controller.restoreFocus("form");
            }
        }
    }
}
