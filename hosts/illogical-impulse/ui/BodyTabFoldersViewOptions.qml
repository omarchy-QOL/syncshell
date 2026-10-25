import QtQuick
import QtQuick.Layouts
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var style
    required property var controller
    readonly property var allGroups: ["ready", "active", "errors", "paused", "unknown"]
    SharedWidgetNativeText { style: root.style; text: "Show folders"; Layout.fillWidth: true }
    GridLayout {
        columns: 2
        Layout.fillWidth: true
        Repeater {
            model: ["all"].concat(root.allGroups)
            SharedWidgetBusyButton {
                required property string modelData
                objectName: "group-" + modelData
                style: root.style
                Layout.fillWidth: true
                selected: modelData === "all" ? root.controller.groups.length > 0 : root.controller.groups.indexOf(modelData) >= 0
                selectionState: modelData === "all" && root.controller.groups.length > 0 && root.controller.groups.length < 5
                    ? "mixed" : selected ? "checked" : "empty"
                text: modelData[0].toUpperCase() + modelData.slice(1)
                help: modelData === "unknown" ? "Current status unavailable; last reported diagnostics are retained" : "Show " + modelData + " folders"
                onClicked: root.controller.groups = modelData === "all"
                    ? (root.controller.groups.length === 5 ? [] : root.allGroups.slice())
                    : Model.toggle(root.controller.groups, modelData)
            }
        }
    }
    SharedWidgetNativeText { style: root.style; text: "Sort"; Layout.fillWidth: true }
    Repeater {
        model: [{id: "name", label: "Name A-Z"}, {id: "active", label: "Active first"}, {id: "errors", label: "Errors first"}]
        SharedWidgetBusyButton {
            required property var modelData
            objectName: "sort-" + modelData.id
            Layout.fillWidth: true
            style: root.style
            text: modelData.label
            selected: root.controller.sort === modelData.id
            onClicked: root.controller.sort = modelData.id
        }
    }
    RowLayout {
        SharedWidgetBusyButton { objectName: "reset-view"; style: root.style; text: "Reset defaults"; onClicked: root.controller.resetView() }
        SharedWidgetBusyButton { objectName: "view-options-back"; style: root.style; text: "Back"; onClicked: root.controller.viewOptionsOpen = false }
    }
}
