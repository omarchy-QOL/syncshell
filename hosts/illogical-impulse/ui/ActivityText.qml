import QtQuick

NativeText {
    id: root
    objectName: "activity-" + folderId
    property var service
    property string folderId: ""
    readonly property bool fresh: service && service.online && service.connection.fresh
    readonly property string detail: service && (!folderId || service.currentActivity.folderId === folderId)
        ? service.activityText : ""
    property int frame: 0
    tone: !fresh ? "muted" : service && service.currentActivity.action === "removing" ? "danger"
        : service && service.currentActivity.action === "upload" ? "success" : "accent"
    text: detail ? (fresh ? "" : "Last reported: ") + detail + (fresh ? ["", ".", "..", "..."][frame] : "") : ""
    visible: text !== ""
    Timer {
        interval: 400
        running: root.visible && root.fresh
        repeat: true
        onTriggered: root.frame = (root.frame + 1) % 4
    }
}
