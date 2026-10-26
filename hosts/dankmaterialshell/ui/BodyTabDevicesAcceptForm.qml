import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets
import "UiConstants.js" as UiConstants

ColumnLayout {
    id: root
    required property var controller
    spacing: Theme.spacingS
    BodyFormHeader {
        Layout.fillWidth: true
        title: "Accept remote device"
        enabled: !root.controller.submitting
        onCancelled: root.controller.closeForm()
    }
    StyledText {
        text: "Remote device name"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.onSurfaceVariant
    }
    DTextField {
        Layout.fillWidth: true
        implicitHeight: UiConstants.CONTROL_HEIGHT + 4
        topPadding: 2
        bottomPadding: 2
        font.pixelSize: Theme.fontSizeSmall
        text: root.controller.draft.name || ""
        enabled: !root.controller.busy
        onTextEdited: root.controller.setDraft("name", text)
    }
    SharedWidgetInfoPair {
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
    SharedWidgetIdCopyButton {
        value: root.controller.draft.deviceId || ""
        caption: "device ID"
        helpText: "Copy device ID"
    }
    SharedWidgetBusyButton {
        Layout.fillWidth: true
        text: "Accept device"
        primary: true
        busy: root.controller.submitting
        enabled: !!root.controller.service && root.controller.service.online
        onClicked: root.controller.submit()
    }
}
