import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../models/PanelModel.js" as Model

StyledText {
    id: root
    property var service: null
    property string folderId: ""
    text: service && service.online && service.connection.fresh && folderId && service.currentActivity.folderId === folderId ? service.activityText : ""
    textFormat: Text.PlainText
    wrapMode: Text.NoWrap
    elide: Text.ElideMiddle
    color: Theme[Model.activityRole(service ? service.currentActivity.action : "")]
    visible: text !== ""
    SharedWidgetToolTip {
        anchors.fill: parent
        text: root.text
    }
}
