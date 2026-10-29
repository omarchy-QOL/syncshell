import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins as Plugins
import "../controllers"

// DMS shows plugin settings as a page in its settings window, not as
// Omarchy's in-panel SettingsMenu; hence the different file name.
Plugins.PluginSettings {
    id: root
    // DMS 2.0 loads settings by URL without setting this required property.
    pluginId: "syncshell"
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
            DDropdown {
                Layout.fillWidth: true
                text: "Icon"
                options: ["Themed", "Branded"]
                currentValue: root.settings.values.iconStyle === "themed" ? "Themed" : "Branded"
                onValueChanged: value => root.settings.save("iconStyle", value === "Themed" ? "themed" : "branded")
            }
            DDropdown {
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
            // Settings live in the DMS window, so its own buttons fit better
            // than the panel's compact ones.
            DButton {
                text: !!root.host && root.host.theme.busy ? "Applying..." : "Apply Web UI selection"
                enabled: !!root.host && !!root.host.service && root.host.service.online && !root.host.theme.busy
                onClicked: root.host.theme.schedule()
            }
            RowLayout {
                Layout.fillWidth: true
                DTextField {
                    Layout.fillWidth: true
                    labelText: "Probe interval (seconds)"
                    text: String(root.settings.values.probeIntervalSeconds)
                    validator: IntValidator {
                        bottom: 1
                        top: 3600
                    }
                    onEditingFinished: root.settings.save("probeIntervalSeconds", Number(text))
                }
                DTextField {
                    Layout.fillWidth: true
                    labelText: "Refresh interval (seconds)"
                    text: String(root.settings.values.refreshIntervalSeconds)
                    validator: IntValidator {
                        bottom: 60
                        top: 3600
                    }
                    onEditingFinished: root.settings.save("refreshIntervalSeconds", Number(text))
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: "Service control is optional. Authorize only the exact user service belonging to this Syncthing instance. The core verifies the match before allowing changes."
                wrapMode: Text.WordWrap
                color: Theme.onSurfaceVariant
            }
            DTextField {
                Layout.fillWidth: true
                labelText: "Systemd user unit"
                text: root.settings.values.lifecycleUnit
                onEditingFinished: root.settings.save("lifecycleUnit", text)
            }
            DTextField {
                Layout.fillWidth: true
                labelText: "Service-bound config path (optional)"
                text: root.settings.values.lifecycleConfig
                onEditingFinished: root.settings.save("lifecycleConfig", text)
            }
            DToggle {
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
                color: Theme.onSurfaceVariant
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
                DTextField {
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
                color: Theme.onSurfaceVariant
            }
            DButton {
                text: "Prepare plugin removal"
                enabled: !!root.host && !!root.host.service && root.host.service.online && !root.host.theme.busy
                onClicked: root.confirmCleanup = true
            }
            RowLayout {
                visible: root.confirmCleanup
                DButton {
                    text: "Cancel"
                    onClicked: root.confirmCleanup = false
                }
                DButton {
                    text: !!root.host && root.host.theme.busy ? "Cleaning..." : "Restore default and clean profiles"
                    enabled: !!root.host && !root.host.theme.busy
                    onClicked: {
                        if (root.host && root.host.theme.cleanup())
                            root.confirmCleanup = false;
                    }
                }
            }
        }
    }
}
