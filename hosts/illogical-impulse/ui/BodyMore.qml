import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var style
    required property var controller
    readonly property var service: controller.service
    readonly property bool fresh: service.online && service.connection.fresh
    objectName: "diagnostics"
    spacing: style.spacing
    SharedWidgetNativeText {
        objectName: "diagnostic-summary"
        style: root.style
        Layout.fillWidth: true
        tone: root.controller.diagnosticRows.length ? "danger" : root.fresh ? "success" : "muted"
        text: root.controller.diagnosticRows.length
            ? (root.fresh ? "Current errors" : "Last reported errors; current status unavailable")
            : root.fresh ? "Clean: no folder errors reported" : "Current folder status unavailable"
    }
    Repeater {
        model: root.controller.diagnosticRows
        ColumnLayout {
            id: diagnostic
            required property var modelData
            objectName: "diagnostic-" + modelData.id
            Layout.fillWidth: true
            SharedWidgetNativeText {
                style: root.style
                Layout.fillWidth: true
                text: diagnostic.modelData.label + " · " + diagnostic.modelData.id
                tone: "danger"
            }
            SharedWidgetInfoPair {
                style: root.style
                Layout.fillWidth: true
                label: "Affected"
                value: diagnostic.modelData.path
            }
            SharedWidgetNativeText {
                style: root.style
                Layout.fillWidth: true
                text: diagnostic.modelData.reason
                visible: text !== ""
                tone: "danger"
            }
            Repeater {
                model: diagnostic.modelData.errors
                SharedWidgetNativeText {
                    required property var modelData
                    style: root.style
                    Layout.fillWidth: true
                    text: (modelData.path || "Folder") + ": " + (modelData.error || "Unknown error")
                    tone: "danger"
                }
            }
            SharedWidgetNativeText {
                objectName: "diagnostic-count-" + diagnostic.modelData.id
                style: root.style
                Layout.fillWidth: true
                muted: true
                text: "Showing " + diagnostic.modelData.shown + " of " + diagnostic.modelData.total
                    + (root.fresh ? " current errors" : " last reported errors")
                    + (diagnostic.modelData.shown < diagnostic.modelData.total ? ". Open Web UI for the full list." : "")
            }
        }
    }
    SharedWidgetInfoPair {
        style: root.style
        Layout.fillWidth: true
        label: "Freshness"
        value: root.fresh ? "Current" : "Stale / unavailable"
    }
    SharedWidgetInfoPair {
        style: root.style
        Layout.fillWidth: true
        label: "Endpoint"
        value: root.service.connection.endpoint || "Discovering"
    }
    SharedWidgetInfoPair {
        style: root.style
        Layout.fillWidth: true
        label: "Version"
        value: root.service.identity.version || "Unknown"
    }
    SharedWidgetInfoPair {
        style: root.style
        Layout.fillWidth: true
        label: "Installation"
        value: root.service.installation.executablePath || "Not detected"
    }
    SharedWidgetBusyButton {
        objectName: "installation-help"
        style: root.style
        text: "Installation help"
        help: "Syncthing installation is managed outside this plugin"
        onClicked: Qt.openUrlExternally("https://docs.syncthing.net/intro/getting-started.html")
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        muted: true
        text: root.service.installation.executablePath
            ? "For an incomplete installation, repair Syncthing using your system package manager. Externally managed services must be started by their owner."
            : "Install Syncthing using your system package manager, then refresh. This plugin does not install system packages."
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        text: root.service.lifecycle.error || ""
        visible: text !== ""
        tone: "danger"
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        text: Object.keys(root.service.truncation).length ? "Some results were truncated. Open Web UI for the complete list." : ""
        visible: text !== ""
        tone: "warning"
    }
}
