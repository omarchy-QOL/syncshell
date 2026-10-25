import QtQuick
import Quickshell
import qs.syncshell as Syncshell
import "ui"
import "models/PanelModel.js" as Model

Item {
    id: root
    readonly property var host: Syncshell.Registry.owner
    implicitWidth: 32
    implicitHeight: 32
    visible: host !== null && host.enabled
    Loader {
        anchors.fill: parent
        active: root.host !== null && root.host.style !== null
        sourceComponent: SharedWidgetBusyButton {
            style: root.host.style
            text: ""
            accessibleLabel: "Syncshell"
            help: root.host.service.summaryText + " · Left/right click to open Syncshell"
            selected: root.host.opened
            onClicked: root.host.toggle(root)
            onAlternate: root.host.toggle(root)
            SharedWidgetMonoIcon {
                style: root.host.style
                monochrome: root.host.settings.values.monochrome
                anchors.centerIn: parent
                width: 20
                height: 20
                source: Qt.resolvedUrl("../../assets/" + (root.host.settings.values.monochrome ? "mono/" : "") + "status-" + Model.iconVariant(root.host.service) + ".svg")
            }
        }
    }
}
