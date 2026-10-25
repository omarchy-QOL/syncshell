import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var host
    readonly property var style: host.style
    readonly property var settings: host.settings
    spacing: style.spacing
    enabled: !settings.saving
    Component.onCompleted: Qt.callLater(probe.focusControl)
    BodyFormHeader {
        style: root.style
        title: "Syncshell settings"
        Layout.fillWidth: true
        onCanceled: root.settings.cancel()
    }
    RowLayout {
        SharedWidgetNativeText {
            style: root.style
            text: "Monochrome icon"
            Layout.fillWidth: true
        }
        Loader {
            id: toggle
            objectName: "settings-monochrome"
            readonly property bool navigationControl: true
            function focusControl() { if (item) item.forceActiveFocus(); }
            sourceComponent: root.style.toggle
            Binding {
                target: toggle.item
                property: "checked"
                value: root.settings.draft.monochrome === true
            }
            Connections {
                target: toggle.item
                function onToggled() {
                    root.settings.edit("monochrome", toggle.item.checked);
                }
            }
        }
    }
    SharedWidgetFormField {
        id: probe
        style: root.style
        Layout.fillWidth: true
        objectName: "settings-probe"
        label: "Probe interval (1–3600 seconds)"
        text: String(root.settings.draft.probeIntervalSeconds || "")
        onEdited: value => root.settings.edit("probeIntervalSeconds", value)
    }
    SharedWidgetFormField {
        style: root.style
        Layout.fillWidth: true
        objectName: "settings-refresh"
        label: "Refresh interval (60–3600 seconds)"
        text: String(root.settings.draft.refreshIntervalSeconds || "")
        onEdited: value => root.settings.edit("refreshIntervalSeconds", value)
    }
    SharedWidgetDropdown {
        style: root.style
        controller: root.host.controller
        Layout.fillWidth: true
        selectorKey: "webui-profile"
        label: "Web UI: " + (root.settings.draft.webUi || "default")
        selectedId: root.settings.draft.webUi || "default"
        options: [
            {
                id: "default",
                label: "Syncthing default"
            },
            {
                id: "modern",
                label: "Modern UI"
            },
            {
                id: "themed",
                label: "Host-themed UI"
            }
        ]
        onChosen: id => root.settings.edit("webUi", id)
    }
    SharedWidgetInfoPair {
        style: root.style
        Layout.fillWidth: true
        label: "Saved choice"
        value: root.settings.values.webUi
    }
    SharedWidgetInfoPair {
        objectName: "actual-webui-theme"
        style: root.style
        Layout.fillWidth: true
        label: "Selected theme"
        value: root.host.service.webUi.theme || "Unknown"
    }
    SharedWidgetBusyButton {
        objectName: "reapply-profile"
        style: root.style
        text: "Apply selected choice again"
        help: "Explicitly select this profile even if another control surface changed the shared Syncthing theme"
        enabled: root.host.service.online && !root.host.controller.blocked
        onClicked: root.settings.save(root.style.palette, true)
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        text: root.host.paletteController.error
        tone: "danger"
        visible: text !== ""
    }
    SharedWidgetBusyButton {
        objectName: "retry-palette"
        style: root.style
        text: "Retry host colors"
        visible: root.host.paletteController.error !== ""
        enabled: root.host.paletteController.selected && root.host.service.online && !root.host.controller.blocked
        onClicked: root.host.paletteController.retry()
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        text: root.settings.error
        visible: text !== ""
    }
    SharedWidgetBusyButton {
        style: root.style
        objectName: "save-settings"
        text: "Save settings"
        busy: root.settings.saving
        busyText: "Saving settings"
        onClicked: root.settings.save(root.style.palette)
    }
    SharedWidgetBusyButton {
        style: root.style
        objectName: "cleanup-profiles"
        text: "Restore default and remove owned profiles"
        enabled: root.host.service.online && !root.host.service.busy
        onClicked: source => {
            root.host.controller.rememberTrigger(source);
            root.host.controller.ask("webui.remove-profile", {}, "Clean up Syncshell Web UI profiles?", "Restore the default Syncthing Web UI, then remove only this adapter's owned profiles. Syncthing folders and configuration are kept.");
        }
    }
    SharedWidgetNativeText {
        style: root.style
        Layout.fillWidth: true
        text: "Removal keeps private settings. First clean up profiles above, stop ii, then run: python3 ~/.config/quickshell/ii/syncshell/manage.py remove --target ~/.config/quickshell/ii --shell-stopped. See the host README for profile cleanup retry."
    }
}
