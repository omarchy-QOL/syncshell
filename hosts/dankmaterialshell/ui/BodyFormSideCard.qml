import QtQuick
import qs.Common
import qs.DCommon.Widgets

StyledRect {
    id: root
    required property var controller
    property var parentPopout: null
    property real maximumHeight: 800
    function focusContent() {
        if (!formLoader.item)
            return false;
        if (controller.confirmation)
            formLoader.item.selectCancel();
        else
            formLoader.item.forceActiveFocus();
        return true;
    }
    // Drawn as its own surface beside the popout, so it takes the popout chrome.
    implicitHeight: Math.min(maximumHeight, formLoader.implicitHeight + PopoutMetrics.contentPadding * 2)
    radius: Theme.windowRadius
    color: parentPopout ? parentPopout.surfaceColor : Theme.hostSurface
    border.width: Theme.outlineWidth
    border.color: Theme.outlineVariant
    DFlickable {
        anchors.fill: parent
        anchors.margins: PopoutMetrics.contentPadding
        contentHeight: formLoader.implicitHeight
        clip: true
        Loader {
            id: formLoader
            width: parent.width
            onLoaded: Qt.callLater(root.focusContent)
            sourceComponent: root.controller.confirmation ? confirmation : root.controller.form === "add-folder" ? folder : root.controller.form === "add-device" ? device : root.controller.form === "accept-device" ? accept : root.controller.form === "share-folder" ? sharing : root.controller.form === "device-folders" ? deviceFolders : null
        }
    }
    Component {
        id: confirmation
        SharedDialogConfirm {
            controller: root.controller
        }
    }
    Component {
        id: folder
        BodyTabFoldersAddForm {
            controller: root.controller
            parentPopout: root.parentPopout
        }
    }
    Component {
        id: device
        BodyTabDevicesAddForm {
            controller: root.controller
            parentPopout: root.parentPopout
        }
    }
    Component {
        id: accept
        BodyTabDevicesAcceptForm {
            controller: root.controller
        }
    }
    Component {
        id: sharing
        BodyTabFoldersShareForm {
            controller: root.controller
            parentPopout: root.parentPopout
        }
    }
    Component {
        id: deviceFolders
        BodyTabDevicesFoldersForm {
            controller: root.controller
            parentPopout: root.parentPopout
        }
    }
}
