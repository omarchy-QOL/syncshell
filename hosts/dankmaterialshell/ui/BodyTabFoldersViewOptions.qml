import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

ColumnLayout {
    id: root
    required property var controller
    GridLayout {
        columns: 2
        Layout.fillWidth: true
        DankToggle {
            text: root.controller.groups.length > 0 && root.controller.groups.length < 5 ? "All (mixed)" : "All"
            checked: root.controller.groups.length === 5
            onToggled: checked => root.controller.groups = checked ? ["ready", "active", "errors", "paused", "unknown"] : []
        }
        Repeater {
            model: ["ready", "active", "errors", "paused", "unknown"]
            DankToggle {
                required property string modelData
                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                checked: root.controller.groups.indexOf(modelData) >= 0
                onToggled: root.controller.toggleGroup(modelData)
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
