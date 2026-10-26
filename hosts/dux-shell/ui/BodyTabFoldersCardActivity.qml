import QtQuick
import qs.Common
import qs.DCommon.Widgets

StyledText {
    id: root
    property var service: null
    property string folderId: ""
    text: service && service.online && service.connection.fresh && folderId && service.currentActivity.folderId === folderId ? service.activityText : ""
    textFormat: Text.PlainText
    maximumLineCount: 1
    elide: Text.ElideMiddle
    color: Theme.onSurfaceVariant
    visible: text !== ""
    SharedWidgetToolTip {
        anchors.fill: parent
        text: root.text
    }
}
