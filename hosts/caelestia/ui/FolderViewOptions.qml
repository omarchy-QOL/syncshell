pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.components.controls
import "."
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var controller
    readonly property var groups: ["ready", "active", "errors", "paused", "unknown"]
    readonly property var selected: controller ? controller.view.filters : []
    readonly property int count: groups.filter(g => selected.includes(g)).length
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        Repeater {
            model: [
                {
                    value: "all",
                    label: root.count > 0 && root.count < root.groups.length ? "All (mixed)" : "All"
                },
                {
                    value: "ready",
                    label: "Ready"
                },
                {
                    value: "active",
                    label: "Active"
                },
                {
                    value: "errors",
                    label: "Errors"
                },
                {
                    value: "paused",
                    label: "Paused"
                },
                {
                    value: "unknown",
                    label: "Unknown"
                }
            ]
            BusyButton {
                required property var modelData
                Layout.fillWidth: true
                caption: modelData.label
                isToggle: true
                type: TextButton.Tonal
                checked: modelData.value === "all" ? root.count === root.groups.length : root.selected.includes(modelData.value)
                onClicked: root.controller.update({
                    filters: modelData.value === "all" ? (root.count === root.groups.length ? [] : root.groups.slice()) : Model.toggle(root.selected, modelData.value)
                })
            }
        }
    }
    StyledText {
        text: "Sort folders"
    }
    Repeater {
        model: [
            {
                value: "name",
                label: "Name"
            },
            {
                value: "active",
                label: "Active first"
            },
            {
                value: "errors",
                label: "Errors first"
            }
        ]
        BusyButton {
            required property var modelData
            Layout.fillWidth: true
            caption: modelData.label
            isToggle: true
            type: TextButton.Tonal
            checked: !!root.controller && root.controller.view.sort === modelData.value
            onClicked: root.controller.update({
                sort: modelData.value
            })
        }
    }
    BusyButton {
        caption: "Reset"
        onClicked: root.controller.update({
            filters: root.groups.slice(),
            sort: "name"
        })
    }
}
