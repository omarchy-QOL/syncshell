import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var controller
    property var parentPopout: null
    spacing: Theme.spacingS
    BodyFormHeader {
        Layout.fillWidth: true
        title: "Share " + (root.controller.service && root.controller.service.folder(root.controller.draft.folderId) ? Model.folderName(root.controller.service.folder(root.controller.draft.folderId)) : "folder")
        enabled: !root.controller.submitting
        onCancelled: root.controller.closeForm()
    }
    StyledText {
        visible: root.controller.shareableDeviceOptions.length === 0
        Layout.fillWidth: true
        text: "No remote devices available. Add a remote device below."
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.warning
    }
    StyledText {
        visible: root.controller.shareableDeviceOptions.length > 0
        text: "Share with devices"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.onSurfaceVariant
    }
    SharedWidgetMultiSelect {
        visible: root.controller.shareableDeviceOptions.length > 0
        Layout.fillWidth: true
        placeholder: "Local only"
        parentPopout: root.parentPopout
        options: root.controller.shareableDeviceOptions
        selectedValues: root.controller.draft.ids || []
        enabled: !root.controller.busy
        onToggled: value => root.controller.toggleDraft(value)
    }
    SharedWidgetBusyButton {
        visible: root.controller.shareableDeviceOptions.length > 0
        Layout.fillWidth: true
        text: "Save sharing"
        busyText: "Saving..."
        primary: true
        busy: root.controller.submitting
        enabled: !!root.controller.service && root.controller.service.online
        onClicked: root.controller.submit()
    }
}
