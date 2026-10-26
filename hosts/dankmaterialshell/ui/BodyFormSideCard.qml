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
        if (formLoader.item.focusFirst)
            formLoader.item.focusFirst();
        else
            formLoader.item.forceActiveFocus();
        return true;
    }
    // The edge that touches the popout, so the form reads as opening out of it.
    property string joinedEdge: ""
    // Drawn as its own surface beside the popout, so it takes the popout chrome.
    implicitHeight: Math.min(maximumHeight, formLoader.implicitHeight + PopoutMetrics.contentPadding * 2)
    radius: Theme.windowRadius
    topRightRadius: joinedEdge === "right" ? 0 : radius
    bottomRightRadius: joinedEdge === "right" ? 0 : radius
    topLeftRadius: joinedEdge === "left" ? 0 : radius
    bottomLeftRadius: joinedEdge === "left" ? 0 : radius
    color: parentPopout ? parentPopout.surfaceColor : Theme.hostSurface
    DFlickable {
        anchors.fill: parent
        anchors.margins: PopoutMetrics.contentPadding
        contentHeight: formLoader.implicitHeight
        clip: true
        Loader {
            id: formLoader
            width: parent.width
            onLoaded: Qt.callLater(root.focusContent)
            sourceComponent: root.controller.form === "add-folder" ? folder : root.controller.form === "add-device" ? device : root.controller.form === "accept-device" ? accept : root.controller.form === "share-folder" ? sharing : root.controller.form === "device-folders" ? deviceFolders : null
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
