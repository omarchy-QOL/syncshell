import QtQuick
import QtQuick.Layouts
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var style
    required property var controller
    readonly property var service: controller.service
    RowLayout {
        SharedWidgetMonoIcon {
            style: root.style
            Layout.preferredWidth: root.style.controlHeight + 8
            Layout.preferredHeight: Layout.preferredWidth
            monochrome: root.service.monochromeIcon === true
            source: Qt.resolvedUrl("../../../assets/" + (monochrome ? "mono/" : "")
                + "status-" + Model.iconVariant(root.service) + ".svg")
        }
        SharedWidgetNativeText {
            style: root.style
            text: "Syncshell"
            Layout.fillWidth: true
        }
        SharedWidgetIdCopyButton {
            controller: root.controller
            style: root.style
            value: root.service.localDeviceId
        }
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        text: root.service.deviceName(root.service.localDeviceId) || "This device"
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        text: root.service.summaryText
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        text: root.service.folderCount + " folders · " + root.service.connectedDeviceCount + "/" + root.service.deviceCount + " devices connected"
    }
    SharedWidgetInfoPair {
        style: root.style
        Layout.fillWidth: true
        objectName: "tracked-totals"
        label: "Tracked"
        value: root.controller.tracked.files + " files · " + Model.bytes(root.controller.tracked.bytes)
            + (root.service.online && root.service.connection.fresh ? "" : " (last reported)")
    }
    SharedWidgetDropdown {
        id: serviceChoice
        style: root.style
        controller: root.controller
        Layout.fillWidth: true
        selectorKey: "service"
        label: "Syncthing service" + (root.service.canControlService ? root.service.lifecycle.active ? " · Running" : " · Stopped" : "")
        enabled: root.service.canControlService && !root.controller.blocked
        options: [
            {
                id: "start",
                label: "Start now",
                enabled: root.service.lifecycle.active === false,
                help: "Start the verified user service"
            },
            {
                id: "stop",
                label: "Stop now",
                enabled: root.service.lifecycle.active === true,
                help: "Stop the verified user service; files and configuration are kept"
            },
            {
                id: "enable",
                label: "Enable on login",
                enabled: String(root.service.lifecycle.unitFileState || "").indexOf("enabled") !== 0
            },
            {
                id: "disable",
                label: "Disable on login",
                enabled: root.service.lifecycle.unitFileState !== "disabled"
            }
        ]
        onChosen: id => {
            root.controller.rememberTrigger(serviceChoice);
            root.controller.ask("lifecycle." + id, {}, id + " Syncthing?", "Applies only to the verified syncthing.service user unit.");
        }
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        visible: !root.service.canControlService
        text: "Service control unavailable: " + (root.service.lifecycle.error || "this instance is externally managed or not yet verified")
        muted: true
    }
}
