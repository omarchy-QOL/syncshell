import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Modules.Plugins as Plugins
import "../controllers"

Plugins.PluginSettings {
    id: root
    property var savedSettings: SettingsData.getPluginSettingsForPlugin(pluginId)
    property var host: pluginService ? pluginService.getGlobalVar(pluginId, "host", null) : null
    property bool confirmCleanup: false
    property SettingsController settings: SettingsController {
        pluginId: root.pluginId
        pluginService: root.pluginService
        pluginData: root.savedSettings
    }
    property Connections settingsConnections: Connections {
        target: root.pluginService
        function onPluginDataChanged(id) {
            if (id === root.pluginId)
                root.savedSettings = SettingsData.getPluginSettingsForPlugin(root.pluginId);
        }
        function onGlobalVarChanged(id, name) {
            if (id === root.pluginId && name === "host")
                root.host = root.pluginService.getGlobalVar(id, "host", null);
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: Theme.spacingM
        StyledText {
            Layout.fillWidth: true
            text: root.settings.validationError || root.settings.writeError
            textFormat: Text.PlainText
            visible: text !== ""
            color: Theme.error
            wrapMode: Text.WordWrap
        }
        ColumnLayout {
            Layout.fillWidth: true
            enabled: root.settings.valid
            spacing: Theme.spacingM
            DankDropdown {
                Layout.fillWidth: true
                text: "Icon"
                options: ["Themed", "Branded"]
                currentValue: root.settings.values.iconStyle === "themed" ? "Themed" : "Branded"
                onValueChanged: value => root.settings.save("iconStyle", value === "Themed" ? "themed" : "branded")
            }
            DankDropdown {
                Layout.fillWidth: true
                text: "Web UI"
                options: ["Syncthing default", "Modern", "DMS theme"]
                currentValue: ({
                        default: "Syncthing default",
                        modern: "Modern",
                        dms: "DMS theme"
                    })[root.settings.values.webUiTheme]
                onValueChanged: value => root.settings.save("webUiTheme", value === "Modern" ? "modern" : value === "DMS theme" ? "dms" : "default")
            }
            StyledText {
                Layout.fillWidth: true
                text: root.host ? root.host.theme.error : "Enable the plugin to apply Web UI profiles."
                visible: text !== ""
                textFormat: Text.PlainText
                color: Theme.warning
            }
            BusyButton {
                text: "Apply Web UI selection"
                busy: !!root.host && root.host.theme.busy
                enabled: !!root.host && !!root.host.service && root.host.service.online
                onClicked: root.host.theme.schedule()
            }
            RowLayout {
                Layout.fillWidth: true
                DankTextField {
                    Layout.fillWidth: true
                    labelText: "Probe interval (seconds)"
                    text: String(root.settings.values.probeIntervalSeconds)
                    validator: IntValidator {
                        bottom: 1
                        top: 3600
                    }
                    onEditingFinished: root.settings.save("probeIntervalSeconds", Number(text))
                }
                DankTextField {
                    Layout.fillWidth: true
                    labelText: "Refresh interval (seconds)"
                    text: String(root.settings.values.refreshIntervalSeconds)
                    validator: IntValidator {
                        bottom: 1
                        top: 3600
                    }
                    onEditingFinished: root.settings.save("refreshIntervalSeconds", Number(text))
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: "Service control is optional. Authorize only the exact user service belonging to this Syncthing instance. The core verifies the match before allowing changes."
                wrapMode: Text.WordWrap
                color: Theme.surfaceVariantText
            }
            DankTextField {
                Layout.fillWidth: true
                labelText: "Systemd user unit"
                text: root.settings.values.lifecycleUnit
                onEditingFinished: root.settings.save("lifecycleUnit", text)
            }
            DankTextField {
                Layout.fillWidth: true
                labelText: "Service-bound config path (optional)"
                text: root.settings.values.lifecycleConfig
                onEditingFinished: root.settings.save("lifecycleConfig", text)
            }
            DankToggle {
                Layout.fillWidth: true
                text: "Authorize user service control"
                description: "Permits the matching service to follow the saved enabled/disabled state."
                checked: root.settings.values.lifecycleAuthorized
                onToggled: checked => root.settings.save("lifecycleAuthorized", checked)
            }
            StyledText {
                text: "Connection"
                font.weight: Font.Medium
            }
            StyledText {
                Layout.fillWidth: true
                text: "Leave these fields empty for local discovery. Credentials stay in a private file read by the native core, never in plugin settings. Connection changes restart only the Syncshell worker."
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }
            Repeater {
                model: [
                    {
                        key: "configPath",
                        label: "Syncthing config path"
                    },
                    {
                        key: "endpoint",
                        label: "API endpoint"
                    },
                    {
                        key: "credentialFile",
                        label: "Private credential file path"
                    },
                    {
                        key: "tlsCertificate",
                        label: "Pinned TLS certificate path"
                    },
                    {
                        key: "expectedDeviceId",
                        label: "Expected device ID"
                    }
                ]
                DankTextField {
                    required property var modelData
                    Layout.fillWidth: true
                    labelText: modelData.label
                    text: root.settings.values[modelData.key]
                    onEditingFinished: root.settings.save(modelData.key, text)
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: "Before removing Syncshell, restore the default Web UI and remove this adapter's generated profiles. This keeps Syncthing's files, configuration and other adapters' profiles. Then remove Syncshell through DMS's plugin manager."
                wrapMode: Text.WordWrap
                color: Theme.surfaceVariantText
            }
            DankButton {
                text: "Prepare plugin removal"
                enabled: !!root.host && !!root.host.service && root.host.service.online && !root.host.theme.busy
                onClicked: root.confirmCleanup = true
            }
            RowLayout {
                visible: root.confirmCleanup
                DankButton {
                    text: "Cancel"
                    onClicked: root.confirmCleanup = false
                }
                BusyButton {
                    text: "Restore default and clean profiles"
                    busy: !!root.host && root.host.theme.busy
                    onClicked: {
                        if (root.host && root.host.theme.cleanup())
                            root.confirmCleanup = false;
                    }
                }
            }
        }
    }
}
