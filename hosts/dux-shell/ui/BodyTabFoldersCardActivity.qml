import QtQuick
import qs.Common
import qs.DCommon.Widgets

StyledText {
    id: root
    property var service: null
    property string folderId: ""
    text: service && service.online && service.connection.fresh && folderId && service.currentActivity.folderId === folderId ? service.activityText : ""
    textFormat: Text.PlainText
    wrapMode: Text.NoWrap
    elide: Text.ElideMiddle
    // Work in progress, which DMS shows in its accent.
    color: Theme.primary
    visible: text !== ""
    SharedWidgetToolTip {
        anchors.fill: parent
        text: root.text
    }
}
