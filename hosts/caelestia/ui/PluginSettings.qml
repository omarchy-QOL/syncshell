pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.components.controls
import "."
import "../models/PanelModel.js" as Model

ColumnLayout {
    id: root
    required property var owner
    required property var controller
    property string error: ""
    readonly property var draft: controller.view.settingsDraft || ({})
    function setValue(key, value) {
        var next = Object.assign({}, draft);
        next[key] = value;
        controller.update({
            settingsDraft: next
        });
    }
    InlineFormHeader {
        Layout.fillWidth: true
        title: "Syncshell settings"
        busy: root.controller.busy
        onCancelled: {
            root.controller.update({
                settingsDraft: null
            });
            root.controller.cancelForm();
        }
    }
    StyledText {
        text: "Bar icon"
    }
    SyncshellDropdown {
        Layout.fillWidth: true
        options: ["sync", "cloud_sync", "folder"].map(s => ({
                    value: s,
                    label: s
                }))
        value: root.draft.icon || "sync"
        onChosen: value => root.setValue("icon", value)
    }
    Repeater {
        model: [
            {
                key: "probeSeconds",
                title: "Probe interval (seconds)",
                number: true
            },
            {
                key: "refreshSeconds",
                title: "Refresh interval (seconds)",
                number: true
            },
            {
                key: "configPath",
                title: "Syncthing configuration path"
            },
            {
                key: "endpoint",
                title: "Endpoint (optional)"
            },
            {
                key: "credentialFile",
                title: "Credential file (optional)"
            },
            {
                key: "tlsCertificate",
                title: "TLS certificate (optional)"
            },
            {
                key: "expectedDeviceId",
                title: "Expected Device ID (optional)"
            },
            {
                key: "lifecycleUnit",
                title: "Exact systemd user unit"
            },
            {
                key: "lifecycleConfig",
                title: "Exact service configuration path"
            }
        ]
        StyledTextField {
            required property var modelData
            Layout.fillWidth: true
            placeholderText: modelData.title
            text: String(root.draft[modelData.key] ?? "")
            readOnly: root.controller.busy
            onTextEdited: root.setValue(modelData.key, modelData.number ? Number(text) : text)
        }
    }
    RowLayout {
        StyledText {
            Layout.fillWidth: true
            text: "Authorize this exact service binding"
            wrapMode: Text.Wrap
        }
        StyledSwitch {
            checked: root.draft.lifecycleAuthorized === true
            onToggled: root.setValue("lifecycleAuthorized", checked)
        }
    }
    StyledText {
        Layout.fillWidth: true
        text: "External instances remain status-only. The core verifies that the unit owns the selected configuration."
        wrapMode: Text.Wrap
    }
    BusyButton {
        caption: "Save settings"
        busy: root.controller.busy
        onClicked: {
            root.error = root.owner.preferences.save(root.draft);
            if (!root.error) {
                root.owner.adapter.core.restart();
                root.controller.update({
                    settingsDraft: null
                });
                root.controller.cancelForm();
            }
        }
    }
    StyledText {
        Layout.fillWidth: true
        visible: !!root.error
        text: root.error
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    BusyButton {
        caption: root.owner.adapter.lifecycle.unitFileState === "enabled" ? "Disable service autostart" : "Enable service autostart"
        disabled: root.controller.busy || !root.owner.adapter.canControlService
        onClicked: root.controller.confirm(root.owner.adapter.lifecycle.unitFileState === "enabled" ? "lifecycle.disable" : "lifecycle.enable", {}, caption + "?", "Change startup for the verified user service.")
    }
    StyledText {
        text: "Syncthing Web UI"
    }
    SyncshellDropdown {
        Layout.fillWidth: true
        options: [
            {
                value: "default",
                label: "Default Syncthing UI"
            },
            {
                value: "modern",
                label: "Modern UI"
            },
            {
                value: "themed",
                label: "Caelestia theme"
            }
        ]
        value: root.draft.webUiStyle || "default"
        onChosen: value => root.setValue("webUiStyle", value)
    }
    BusyButton {
        caption: "Apply Web UI selection"
        busy: root.controller.busy
        onClicked: root.owner.applyWebUi(root.draft.webUiStyle)
    }
    BusyButton {
        caption: "Restore default UI and clean owned profiles"
        label.width: width - horizontalPadding * 2
        label.wrapMode: Text.Wrap
        Layout.fillWidth: true
        busy: root.controller.busy
        onClicked: root.controller.confirm("webui.remove-profile", {}, "Restore and clean profiles?", "Restore Syncthing's default Web UI and remove only Caelestia-owned profiles. Do this before uninstalling the plugin.")
    }
    StyledText {
        Layout.fillWidth: true
        text: "Web UI changes are explicit. Palette updates apply only while this adapter's themed profile is selected."
        wrapMode: Text.Wrap
    }
    Component.onCompleted: if (!controller.view.settingsDraft)
        controller.update({
            settingsDraft: Model.clone(owner.preferences.values())
        })
}
