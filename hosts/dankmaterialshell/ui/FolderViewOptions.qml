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
            text: root.controller.groups.length === 5 ? "All" : "All (mixed)"
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
            DankButton {
                required property var modelData
                text: modelData.label
                textColor: root.controller.sort === modelData.value ? Theme.primary : Theme.surfaceText
                onClicked: root.controller.sort = modelData.value
            }
        }
    }
    DankButton {
        text: "Reset filters"
        onClicked: root.controller.resetFilters()
    }
}
