pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import "../../shared" as Shared
import "controllers"
import "models/Ownership.js" as Ownership

QtObject {
    id: root
    property var plugin: null
    property var settings: null
    property int ownerGeneration: -1
    property var owners: []
    property var predecessor: null
    property bool retired: false
    property bool awaitingExit: false
    property string pendingStyle: ""
    property string lastPaletteAttempt: ""
    property var views: ({})
    property var pinnedOverviews: ({})
    readonly property Shared.AdapterService adapter: worker.item as Shared.AdapterService
    readonly property bool eligible: plugin && plugin.enabled && !retired && plugin.generation === ownerGeneration && owners.length > 0 && preferences.valid

    function attach(entry, injectedSettings) {
        if (!plugin) {
            plugin = entry.plugin;
            ownerGeneration = plugin.generation;
            predecessor = Ownership.claim(root);
        }
        settings = injectedSettings;
    }
    function acquire(entry, injectedSettings, token) {
        attach(entry, injectedSettings);
        if (!owners.includes(token))
            owners = owners.concat([token]);
        Qt.callLater(maybeStart);
    }
    function pinOverview(screenName, pinned) {
        if (!!pinnedOverviews[screenName] === pinned)
            return;
        let next = Object.assign({}, pinnedOverviews);
        if (pinned)
            next[screenName] = true;
        else
            delete next[screenName];
        pinnedOverviews = next;
    }
    function hasScreen(name) {
        return owners.some(owner => owner.screenName === name);
    }
    function release(token) {
        owners = owners.filter(value => value !== token);
        if (token.screenName && !hasScreen(token.screenName) && views[token.screenName]) {
            let next = Object.assign({}, views);
            next[token.screenName].retire();
            next[token.screenName].destroy();
            delete next[token.screenName];
            views = next;
        }
        if (!owners.length && adapter)
            adapter.core.terminate();
    }
    function retire() {
        retired = true;
        Object.values(views).forEach(controller => {
            controller.retire();
            controller.destroy();
        });
        views = {};
        settings = null;
        paletteUpdate.stop();
        if (adapter)
            adapter.core.terminate();
    }
    function maybeStart() {
        if (!adapter || !eligible || predecessor && predecessor.adapter && predecessor.adapter.core.running)
            return;
        predecessor = null;
        if (adapter.core.running) {
            awaitingExit = !adapter.core.desiredRunning;
            return;
        }
        awaitingExit = false;
        adapter.core.start();
    }
    function controller(screenName) {
        if (!views[screenName]) {
            let next = Object.assign({}, views);
            next[screenName] = controllerComponent.createObject(root, {
                service: adapter,
                screenName: screenName
            });
            views = next;
        }
        return views[screenName];
    }
    function applyWebUi(style) {
        if (!eligible || !adapter || adapter.busy || adapter.refreshing)
            return false;
        var accepted = style === "default" ? adapter.setWebUiTheme("default") : adapter.applyWebProfile(style, style === "themed" ? theme.palette : {});
        if (accepted) {
            pendingStyle = style;
            if (style === "themed")
                lastPaletteAttempt = JSON.stringify(theme.palette);
        }
        return accepted;
    }
    property Timer paletteUpdate: Timer {
        interval: 300
        onTriggered: {
            if (root.eligible && root.adapter.online && !root.adapter.busy && !root.adapter.refreshing && root.adapter.webUi.theme === "syncshell-caelestia-themed" && root.lastPaletteAttempt !== JSON.stringify(root.theme.palette))
                root.applyWebUi("themed");
        }
    }
    property Connections paletteChanges: Connections {
        target: root.theme
        function onPaletteChanged() {
            root.paletteUpdate.restart();
        }
    }
    property Connections profileResults: Connections {
        target: root.adapter
        function onBusyChanged() {
            if (!root.adapter.busy)
                root.paletteUpdate.restart();
        }
        function onWebUiChanged() {
            root.paletteUpdate.restart();
        }
        function onActionFinished(action, ok, data, error) {
            if (action !== "webui.apply-profile" && action !== "webui.set-theme" && action !== "webui.remove-profile")
                return;
            if (ok && root.settings) {
                root.settings.webUiStyle = action === "webui.remove-profile" ? "default" : root.pendingStyle || root.settings.webUiStyle;
            }
            root.pendingStyle = "";
        }
    }
    onEligibleChanged: {
        if (!eligible && adapter)
            adapter.core.terminate();
        else
            Qt.callLater(maybeStart);
    }
    property Connections previousWorker: Connections {
        target: root.predecessor ? root.predecessor.adapter.core : null
        function onRunningChanged() {
            root.maybeStart();
        }
    }
    property Connections manifest: Connections {
        target: root.plugin
        function onGenerationChanged() {
            if (root.plugin.generation !== root.ownerGeneration)
                root.retire();
        }
        function onSettingsChanged() {
            if (!root.retired)
                root.settings = root.plugin.settings;
        }
    }
    property Connections executable: Connections {
        target: root.adapter ? root.adapter.core : null
        function onExecutableReadyChanged() {
            root.maybeStart();
        }
        function onRunningChanged() {
            if (root.awaitingExit && !root.adapter.core.running)
                root.maybeStart();
        }
    }
    property Component controllerComponent: Component {
        PanelController {}
    }
    property SettingsController preferences: SettingsController {
        settings: root.settings
    }
    property ThemePaletteController theme: ThemePaletteController {
    }
    property Loader worker: Loader {
        active: !!root.plugin
        onLoaded: Qt.callLater(root.maybeStart)
        sourceComponent: Shared.AdapterService {
            startCore: false
            bundleRoot: root.plugin ? root.plugin.dir : ""
            probeIntervalSeconds: root.preferences.valid ? root.settings.probeSeconds : 15
            refreshIntervalSeconds: root.preferences.valid ? root.settings.refreshSeconds : 60
            desktopAuthorized: true
            profilePolicy: ({
                    authorized: true,
                    owner: "caelestia",
                    bundle: bundleRoot + "/webui"
                })
            lifecyclePolicy: root.preferences.valid && root.settings.lifecycleAuthorized ? {
                authorized: true,
                kind: "systemd-user",
                unit: root.settings.lifecycleUnit,
                configPath: root.settings.lifecycleConfig
            } : ({})
            configPath: root.preferences.valid ? root.settings.configPath : ""
            endpoint: root.preferences.valid ? root.settings.endpoint : ""
            credentialFile: root.preferences.valid ? root.settings.credentialFile : ""
            tlsCertificate: root.preferences.valid ? root.settings.tlsCertificate : ""
            expectedDeviceId: root.preferences.valid ? root.settings.expectedDeviceId : ""
        }
    }
    Component.onDestruction: if (adapter)
        adapter.core.terminate()
}
