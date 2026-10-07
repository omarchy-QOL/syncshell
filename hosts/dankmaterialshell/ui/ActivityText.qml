import QtQuick
import qs.Common
import qs.Widgets

StyledText {
    id: root
    property var service: null
    property string folderId: ""
    text: service && (!folderId || service.currentActivity.folderId === folderId) ? service.activityText : ""
    textFormat: Text.PlainText
    maximumLineCount: 1
    elide: Text.ElideMiddle
    color: Theme.surfaceVariantText
    visible: text !== ""
    SyncshellToolTip {
        anchors.fill: parent
        text: root.text
    }
}
