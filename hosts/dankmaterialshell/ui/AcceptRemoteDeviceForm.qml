import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

ColumnLayout {
    id: root
    required property var controller
    spacing: Theme.spacingS
    InlineFormHeader {
        Layout.fillWidth: true
        title: "Accept remote device"
        enabled: !root.controller.submitting
        onCancelled: root.controller.closeForm()
    }
    DankTextField {
        Layout.fillWidth: true
        labelText: "Remote device name"
        text: root.controller.draft.name || ""
        enabled: !root.controller.busy
        onTextEdited: root.controller.setDraft("name", text)
    }
    InfoPair {
        Layout.fillWidth: true
        label: "Address"
        value: root.controller.draft.address || "Unknown"
    }
    StyledText {
        Layout.fillWidth: true
        text: root.controller.draft.deviceId || ""
        textFormat: Text.PlainText
        wrapMode: Text.WrapAnywhere
        elide: Text.ElideNone
    }
    BusyButton {
        Layout.fillWidth: true
        text: "Accept device"
        busy: root.controller.submitting
        enabled: !!root.controller.service && root.controller.service.online
        onClicked: root.controller.submit()
    }
}
