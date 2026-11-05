import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets

ColumnLayout {
    id: root
    required property var controller
    // Buttons like the sort row below: DToggle's labels fell outside this list.
    GridLayout {
        columns: 3
        Layout.fillWidth: true
        SharedWidgetTooltipButton {
            Layout.fillWidth: true
            text: root.controller.groups.length > 0 && root.controller.groups.length < 5 ? "All (mixed)" : "All"
            checked: root.controller.groups.length === 5
            onClicked: root.controller.groups = checked ? [] : ["ready", "active", "errors", "paused", "unknown"]
        }
        Repeater {
            model: ["ready", "active", "errors", "paused", "unknown"]
            SharedWidgetTooltipButton {
                required property string modelData
                Layout.fillWidth: true
                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                checked: root.controller.groups.indexOf(modelData) >= 0
                onClicked: root.controller.toggleGroup(modelData)
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
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
            SharedWidgetTooltipButton {
                required property var modelData
                text: modelData.label
                checked: root.controller.sort === modelData.value
                onClicked: root.controller.sort = modelData.value
            }
        }
    }
    SharedWidgetTooltipButton {
        text: "Reset filters"
        onClicked: root.controller.resetFilters()
    }
}
