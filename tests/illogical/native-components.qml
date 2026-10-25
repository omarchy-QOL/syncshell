//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import qs.syncshell as Syncshell
import qs.modules.common as Common
import qs.modules.waffle.looks as Looks
import "syncshell/hosts/illogical-impulse/ui/ii" as Material
import "syncshell/hosts/illogical-impulse/ui/waffle" as Waffle
import "syncshell/hosts/illogical-impulse/ui" as UI
import "syncshell/hosts/illogical-impulse/controllers" as Controllers
import "syncshell/hosts/illogical-impulse/models/PanelModel.js" as Model

ShellRoot {
    id: root
    readonly property string localId: Array(8).fill("AAAAAAA").join("-")
    readonly property string peerId: Array(8).fill("BBBBBBB").join("-")
    readonly property string requestId: Array(8).fill("CCCCCCC").join("-")
    readonly property string nearbyId: Array(8).fill("DDDDDDD").join("-")
    property int familyIndex: 0
    property int step: 0
    property int stalledTicks: 0
    property real oldHeight: 0
    property var originalFolders: []
    property bool presented: true
    Material.NativeStyle { id: material }
    Waffle.NativeStyle { id: waffle }
    QtObject {
        id: fixtureHost
        property bool enabled: true
        property bool opened: false
        property int toggles: 0
        function toggle(source) { toggles++; opened = !opened; }
        property var style: root.familyIndex ? waffle : material
        property var controller: controller
        property var service: service
        property var settings: settings
        property var paletteController: palette
        function close() { controller.presentationActive = false; root.presented = false; }
    }
    Controllers.SettingsController { id: settings; service: service }
    Controllers.ThemePaletteController { id: palette; service: service; settings: settings; palette: fixtureHost.style.palette }
    QtObject {
        id: service
        property bool busy: false
        property bool online: true
        property bool refreshing: false
        property bool canControlService: false
        property bool monochromeIcon: true
        property string phase: "online"
        property string _actionName: ""
        property string _actionTargetId: ""
        property var calls: []
        property var webUi: ({theme: "default"})
        property var connection: ({fresh: true, endpoint: "http://fixture.invalid"})
        property var lifecycle: ({})
        property var identity: ({version: "fixture"})
        property var installation: ({executablePath: "/fixture/syncthing"})
        property var truncation: ({folderErrors: true})
        property var currentActivity: ({})
        property string activityText: ""
        property string localDeviceId: root.localId
        property int folderCount: folders.length
        property int deviceCount: devices.length
        property int connectedDeviceCount: 1
        property int folderProblemCount: 1
        property int syncingFolderCount: 1
        property string summaryText: "1 folder needs attention"
        property string lastError: ""
        property string actionNotice: ""
        property var folders: [
            {id: "a", label: "Alpha", path: "/tmp/one/docs", devices: [{id: root.peerId, remoteState: "valid"}],
                status: {state: "idle", globalFiles: 123, globalBytes: 4096, errors: []}},
            {id: "b", label: "Beta", path: "/tmp/two/docs", devices: [{id: root.peerId, remoteState: "unknown"}],
                status: {state: "scanning", needTotalItems: 4, globalFiles: 10, globalBytes: 1024, errors: []}},
            {id: "error", label: "Long <b>plain text</b> folder", path: "/tmp/long folder with spaces", devices: [],
                status: {state: "error", error: "Folder stopped", pullErrors: 9,
                    errors: [{path: "nested/file.txt", error: "Permission denied"}]}}
        ]
        property var devices: [{id: root.peerId, name: "Peer", address: "tcp://fixture", connected: true}]
        property var nearbyDevices: [{id: root.nearbyId, name: "Peer", addresses: ["tcp://nearby"]}]
        property var pendingDevices: [{id: root.requestId, name: "<b>plain text</b>", address: "tcp://pending"}]
        property var pendingFolders: [
            {folderId: "offer", deviceId: root.peerId, label: "Same offer", encrypted: false},
            {folderId: "offer", deviceId: root.requestId, label: "Same offer", encrypted: false},
            {folderId: "encrypted", deviceId: root.peerId, label: "Encrypted offer", encrypted: true}
        ]
        signal actionFinished(string action, bool ok, var data, var error)
        function folder(id) { return Model.byId(folders, id); }
        function device(id) { return Model.byId(devices, id); }
        function deviceName(id) { return id === root.localId ? "Fixture host" : "Peer " + id.slice(0, 7); }
        function folderLabel(id) { return folder(id) ? folder(id).label : id; }
        function remoteDevices() { return devices; }
        function shareableDevices() { return devices; }
        function folderIdsForDevice(id) { return folders.filter(row => row.devices.some(member => member.id === id)).map(row => row.id); }
        function remoteDeviceIdsForFolder(id) { return (folder(id).devices || []).map(row => row.id); }
        function pendingFolderOffers() { return pendingFolders; }
        function folderArguments(value) { return Model.clone(value); }
        function runAction(action, args, notice, target) {
            if (busy || !online) return false;
            busy = true; _actionName = action; _actionTargetId = target || "";
            calls = calls.concat([{action: action, args: Model.clone(args), notice: notice}]);
            return true;
        }
        function requestFolderIdSuggestion() { return runAction("folder.suggest-id", {}, "", ""); }
        function openWebUi() { return runAction("webui.open", {}, "", ""); }
        function rescanAllFolders() { return runAction("folder.rescan-all", {}, "", ""); }
        function rescanFolder(id) { return runAction("folder.rescan", {folderId: id}, "", id); }
        function refreshStatus() { return runAction("folder.recheck-errors", {}, "", ""); }
        function recheckErrors() { return refreshStatus(); }
        function setWebUiTheme(theme) { return runAction("webui.set-theme", {theme: theme}, "", ""); }
        function applyWebProfile(profile, colors) { return runAction("webui.apply-profile", {profile: profile, palette: colors}, "", ""); }
        function settle(ok, data, failure) {
            var action = _actionName;
            busy = false; _actionName = ""; _actionTargetId = "";
            actionFinished(action, ok, data || {}, failure || null);
        }
    }
    Controllers.PanelController { id: controller; service: service }
    Window {
        id: window
        visible: true
        width: 850
        height: 800
        color: fixtureHost.style.background
        Loader {
            id: main
            x: 12; y: 12; width: Math.min(420, window.width - 24); height: window.height - 30
            active: root.presented
            sourceComponent: UI.SyncshellPanelPopup { host: fixtureHost }
        }
        Loader {
            id: side
            x: 450; y: 12; width: 380; height: 770
            active: root.presented && (controller.formVisible || controller.confirmationVisible || settings.opened)
            sourceComponent: UI.SyncshellPanelPopup { host: fixtureHost; side: true }
        }
        UI.BodyTabFoldersAddFormPicker { id: picker; controller: controller; parentWindow: window }
        Syncshell.IllogicalBarEntry { id: bar; x: window.width - 40; y: window.height - 40 }
        TestCase { id: input; when: false }
    }
    Component.onCompleted: Syncshell.Registry.owner = fixtureHost
    Component.onDestruction: Syncshell.Registry.owner = null
    function check(value, message) {
        if (!value) { console.error("[fail] " + fixtureHost.style.family + " step " + step + ": " + message); Qt.exit(1); throw Error(message); }
    }
    // Focus and filtering settle on later event-loop turns, which can exceed
    // the step interval on a loaded machine; the condition must still hold.
    function settle(condition, message) {
        for (let waited = 0; !condition() && waited < 2000; waited += 20)
            input.wait(20);
        check(condition(), message);
    }
    function item(name) {
        var value = input.findChild(window.contentItem, name);
        check(value !== null, "find production control " + name);
        return value;
    }
    function click(name) {
        input.wait(180);
        var value = item(name);
        check(value.enabled, name + " enabled");
        if (typeof value.focusControl === "function") value.focusControl();
        if (main.item) main.item.reveal(value);
        if (side.item) side.item.reveal(value);
        input.wait(250);
        var control = value.item || value;
        input.mouseClick(control, control.width / 2, control.height / 2, Qt.LeftButton);
    }
    function edit(name, value) {
        var control = item(name);
        control.focusControl();
        settle(() => control.item.activeFocus, "editor owns keyboard focus: " + name);
        input.keyClick(Qt.Key_A, Qt.ControlModifier);
        check(control.item.selectedText.length === control.item.text.length, "Ctrl+A selects editor contents: " + name);
        input.keyClick(Qt.Key_Backspace);
        for (var index = 0; index < value.length; index++) input.keyClick(value[index]);
    }
    function capture(name) {
        var path = Quickshell.env("SYNCSHELL_CAPTURE_DIR");
        if (path) input.grabImage(window.contentItem).save(path + "/" + fixtureHost.style.family + "-" + name + ".png");
    }
    readonly property var actions: [
        () => {
            var before = fixtureHost.toggles;
            input.mouseClick(bar, 16, 16, Qt.LeftButton);
            input.mouseClick(bar, 16, 16, Qt.RightButton);
            check(fixtureHost.toggles === before + 2 && !fixtureHost.opened, "native bar routes left and right gestures exactly once");
            check(controller.folderId === "a" && controller.deviceId === peerId, "initial stable selections");
            check(controller.tracked.files === 133 && item("tracked-totals").value.indexOf("133 files") >= 0, "tracked totals rendered");
            var disabled = item("forget-disabled-help");
            main.item.reveal(disabled);
            input.wait(300);
            input.mouseMove(disabled, disabled.width / 2, disabled.height / 2);
            input.wait(500);
            settle(() => item("forget-disabled-tooltip").item.visible, "disabled Forget explains pause precondition");
            input.mouseMove(window.contentItem, window.width - 5, 5);
            oldHeight = main.item.implicitHeight;
            click("folder-trigger");
        },
        () => {
            settle(() => item("folder").popupItem.visible, "anchored menu visible");
            check(main.item.implicitHeight === oldHeight, "menu does not reflow panel");
            var popup = item("folder").popupItem;
            check(popup.x >= 0 && popup.y >= 0 && popup.y + popup.height <= window.height, "menu bounded by window");
            edit("folder-search", "/two");
            settle(() => item("folder").filtered.length === 1, "metadata search distinguishes duplicate basenames");
            input.keyClick(Qt.Key_Return);
            check(controller.folderId === "b", "Enter selects exact stable ID");
            click("folder-trigger");
        },
        () => { click("folder-view-options"); check(controller.viewOptionsOpen, "view control opens subview"); },
        () => {
            click("group-ready");
            check(controller.groups.length === 4, "mixed group state");
            click("sort-errors");
            input.keyClick(Qt.Key_Escape);
            check(!controller.viewOptionsOpen && controller.selector === "folder", "Escape dismisses subview only");
            check(controller.queries.folder === "/two", "nested options retain query");
            click("folder-view-options");
        },
        () => { click("reset-view"); click("view-options-back"); input.keyClick(Qt.Key_Escape); },
        () => {
            settle(() => !controller.selector && item("folder-trigger").item.activeFocus, "selector returns focus");
            click("add-folder");
        },
        () => {
            check(controller.view === "add-folder" && controller.preparing, "production add action prepares ID");
            service.settle(false, {}, {message: "ID preparation fixture failure"});
            check(item("folder-preparation-error").text.indexOf("failure") >= 0, "preparation error rendered");
            click("new-folder-id");
            service.settle(true, {folderId: "generated"});
            edit("folder-path", "/tmp/new-directory");
            edit("folder-label", "Created from UI");
            click("browse-directory");
        },
        () => {
            settle(() => picker.visible, "production directory picker opens");
            picker.reject();
            input.wait(20);
            settle(() => item("folder-path").item.activeFocus, "picker cancellation returns editor focus");
            click("browse-directory");
            picker.selectedFolder = "file:///tmp/selected%20directory";
            picker.accept();
        },
        () => {
            check(controller.draft.path === "/tmp/selected directory", "picker decodes selected directory");
            edit("folder-path", "/tmp/new-directory");
            capture("folder-form");
            click("save-folder");
            var callsBeforeRepeat = service.calls.length;
            input.mouseDoubleClickSequence(item("save-folder").item, 10, 10, Qt.LeftButton);
            check(service.calls.length === callsBeforeRepeat, "repeat input does not replay pending submission");
            check(controller.pending && !item("save-folder").enabled, "submission freezes repeat action");
            check(service.calls[service.calls.length - 1].args.path === "/tmp/new-directory", "exact submitted path " + JSON.stringify(service.calls[service.calls.length - 1]));
            service.settle(false, {}, {code: "path_missing", message: "Directory missing"});
        },
        () => {
            settle(() => item("confirmation-cancel").item.activeFocus, "Cancel focused first");
            check(controller.confirmation.args.path === "/tmp/new-directory", "missing-directory target frozen");
            capture("confirmation");
            click("confirmation-submit");
            check(service.calls[service.calls.length - 1].args.createDirectory, "explicit directory creation");
            service.settle(true, {});
        },
        () => {
            check(controller.view === "", "successful creation closes form");
            click("tab-devices");
        },
        () => { check(controller.tab === "devices", "native device tab"); click("add-device"); },
        () => {
            check(!item("save-device").enabled, "empty device ID disabled");
            edit("device-id", localId.toLowerCase());
            check(item("device-validation").text.indexOf("this device") >= 0, "self ID rejected before submission");
            edit("device-id", peerId);
            check(item("device-validation").text.indexOf("already") >= 0, "existing ID rejected");
            click("nearby-trigger");
        },
        () => { edit("nearby-search", "tcp://nearby"); input.keyClick(Qt.Key_Return); },
        () => {
            check(controller.draft.deviceId === nearbyId, "nearby selection uses exact ID");
            edit("device-name", "Renamed peer");
            click("save-device");
            var args = service.calls[service.calls.length - 1].args;
            check(args.deviceId === nearbyId && args.deviceName === "Renamed peer" && Object.keys(args).length === 2, "device submission excludes UI state");
            service.settle(false, {}, {message: "Connection lost"});
        },
        () => {
            check(controller.view === "add-device" && controller.error === "Connection lost", "failure retains editable draft");
            click("cancel");
            click("accept-pending-device");
        },
        () => {
            check(controller.draft.deviceId === requestId && controller.draft.address === "tcp://pending", "accept preserves request identity and address");
            service.pendingDevices = [];
            check(controller.draft.deviceId === requestId, "disappearing request cannot retarget draft");
            check(item("device-id").readOnly, "accepted identity read-only");
            click("copy-request-device-id");
            check(Quickshell.clipboardText === requestId && controller.copiedId === requestId, "copy action and durable feedback preserve frozen ID");
            click("cancel");
            click("pending-folders-trigger");
        },
        () => {
            edit("pending-folders-search", requestId);
            input.keyClick(Qt.Key_Return);
            check(controller.selectedOffer.offer.deviceId === requestId, "same-folder multi-sender choice distinct");
            click("dismiss-pending-folder");
        },
        () => {
            check(controller.confirmation !== null, "dismiss confirmation opens");
            var frozen = controller.confirmation.args;
            check(frozen.folderId === "offer" && frozen.pendingDeviceId === requestId, "dismiss freezes composite offer");
            click("confirmation-cancel");
            click("tab-folders");
            click("folder-trigger");
        },
        () => { edit("folder-search", "error"); input.keyClick(Qt.Key_Return); },
        () => { click("folder-errors"); },
        () => {
            check(controller.more && item("diagnostic-count-error").text.indexOf("1 of 9") >= 0, "diagnostics show total and truncation");
            check(main.item.scrollItem.contentY > 0, "error hint scrolls diagnostics into view");
            service.connection = {fresh: false, endpoint: "http://fixture.invalid"};
            check(item("diagnostic-summary").text.indexOf("Last reported") >= 0, "stale diagnostics remain visible");
            capture("stale-diagnostics");
            service.connection = {fresh: true, endpoint: "http://fixture.invalid"};
            click("folder-trigger");
        },
        () => { edit("folder-search", "/one"); input.keyClick(Qt.Key_Return); click("share-folder"); },
        () => { click("sharing-trigger"); },
        () => {
            settle(() => item("sharing-list").item.activeFocus, "sharing popup owns keyboard focus");
            input.keyClick(Qt.Key_Down); input.keyClick(Qt.Key_Space); input.keyClick(Qt.Key_Escape);
            check(controller.draft.deviceIds.length === 0, "multi-select can remove all shares");
            click("save-sharing");
            check(service.calls[service.calls.length - 1].args.deviceIds.length === 0, "local-only save reaches backend boundary");
            service.settle(true, {});
        },
        () => {
            click("tab-devices");
            click("folders");
        },
        () => {
            check(!item("save-sharing").enabled, "no-op removal disabled");
            click("device-folders-trigger");
        },
        () => {
            settle(() => item("device-folders-list").item.activeFocus, "device folders popup owns keyboard focus");
            input.keyClick(Qt.Key_Down); input.keyClick(Qt.Key_Space); input.keyClick(Qt.Key_Escape);
        },
        () => {
            check(controller.removedShareIds.length === 1 && controller.removedShareIds[0] === "a", "confirmed group retains hidden unconfirmed share");
            click("save-sharing");
        },
        () => {
            check(controller.confirmation.args.folderIds[0] === "a", "removal confirmation targets unchecked share");
            click("confirmation-cancel"); click("cancel");
            var before = service.calls.length;
            item("tab-devices").forceActiveFocus(); input.keyClick(Qt.Key_P);
            check(service.calls.length === before && !controller.confirmation, "hidden folder tab shortcut does not fire");
            click("settings");
        },
        () => {
            check(item("actual-webui-theme").value === "default", "actual shared theme shown separately");
            edit("settings-probe", "0");
            click("save-settings");
            check(settings.error.indexOf("Probe") >= 0, "invalid interval retained");
            edit("settings-probe", "27");
            click("reapply-profile");
            check(service.calls[service.calls.length - 1].action === "webui.set-theme", "same saved default is explicitly reapplied");
            service.settle(false, {}, {message: "Profile failed"});
        },
        () => {
            check(settings.error === "Profile failed" && settings.hasDraft, "profile failure retains settings draft");
            click("cancel");
            click("tab-folders");
            item("share-folder").focusControl();
            input.keyClick(Qt.Key_L);
            settle(() => item("folder-pause").item.activeFocus, "spatial horizontal action navigation");
            input.keyClick(Qt.Key_J);
            check(main.item.scrollItem.contentY >= 0, "navigation scroll remains bounded");
            capture("panel");
            click("add-folder");
            service.settle(true, {folderId: "retained"});
            edit("folder-path", "/tmp/retained-input");
            input.keyClick(Qt.Key_Escape);
            check(!controller.formVisible && controller.draft.path === "/tmp/retained-input", "Escape hides without discarding");
            click("tab-devices"); click("add-device");
        },
        () => {
            check(controller.view === "add-folder" && controller.formVisible && controller.error.indexOf("existing draft") >= 0,
                "conflicting form visibly resumes retained draft");
            click("cancel");
            click("devices-trigger");
        },
        () => {
            edit("devices-search", "Peer");
            controller.presentationActive = false;
            root.presented = false;
        },
        () => {
            check(controller.selector === "devices" && controller.queries.devices === "Peer", "destroyed presentation retains selector intent");
            controller.presentationActive = true;
            root.presented = true;
        },
        () => {
            settle(() => controller.tab === "devices" && item("devices").popupItem.visible, "reconstruction restores tab and open selector");
            check(item("devices-search").text === "Peer", "reconstruction restores selector query");
            input.keyClick(Qt.Key_Escape);
            click("tab-folders");
            check(item("tab-folders").checked, "rendered tab selection follows controller");
            ioPreparation.running = true;
            click("settings");
        },
        () => { edit("settings-probe", String(29 + familyIndex * 2)); click("save-settings"); },
        () => {
            check(settings.error.indexOf("save") >= 0 && settings.hasDraft, "settings IO failure retains draft");
            console.log("[ok] injected settings write failure retained draft " + fixtureHost.style.family);
            ioRecovery.running = true;
        },
        () => { click("save-settings"); },
        () => {
            check(settings.values.probeIntervalSeconds === 29 + familyIndex * 2 && !settings.hasDraft, "settings IO retry persists normalized values");
            originalFolders = service.folders;
            service.folders = Array.from({length: 40}, (_, index) => ({id: "many-" + index,
                label: "Long <i>plain text</i> label " + index, path: "/tmp/" + index + "/docs",
                devices: [], status: {state: "idle", globalFiles: index, errors: []}}));
            window.width = 350;
            window.height = 650;
            if (familyIndex === 0) Common.Appearance.font.pixelSize.small = 22;
            else { Looks.Looks.font.pixelSize.normal = 18; Looks.Looks.font.pixelSize.large = 20; }
            click("folder-trigger");
        },
        () => { edit("folder-search", "many-39"); input.keyClick(Qt.Key_Return); },
        () => { click("folder-trigger"); edit("folder-search", ""); input.keyClick(Qt.Key_Escape); },
        () => { click("folder-trigger"); },
        () => {
            var selector = item("folder"), list = item("folder-list").item;
            settle(() => selector.filtered.length === 40, "many rows remain searchable");
            settle(() => selector.filtered[list.currentIndex].id === "many-39" && list.activeFocus,
                "selected row focused and positioned on reopen");
            check(list.currentItem && list.currentItem.y >= list.contentY - 1
                && list.currentItem.y + list.currentItem.height <= list.contentY + list.height + 1,
                "selected native row is fully visible after measuring long rows");
            settle(() => selector.popupItem.width <= window.width && selector.popupItem.y + selector.popupItem.height <= window.height,
                "narrow large-font menu remains bounded");
            capture("many-narrow-large-font");
            input.keyClick(Qt.Key_L);
        },
        () => {
            check(controller.viewOptionsOpen, "keyboard opens nested view options");
            for (var index = 0; index < 12; index++) input.keyClick(Qt.Key_J);
            check(item("folder-view-scroll").contentY > 0, "large view options scroll with keyboard focus");
            capture("options-narrow-large-font");
            input.keyClick(Qt.Key_Escape); input.keyClick(Qt.Key_Escape);
            service.folders = originalFolders;
            window.width = 850; window.height = 800;
            if (familyIndex === 0) Common.Appearance.font.pixelSize.small = 15;
            else { Looks.Looks.font.pixelSize.normal = 11; Looks.Looks.font.pixelSize.large = 13; }
        },
        () => {
            service.canControlService = true;
            service.lifecycle = {active: true, unitFileState: "enabled"};
            click("service-trigger");
        },
        () => {
            var selector = item("service"), list = item("service-list").item;
            settle(() => list.activeFocus, "service menu owns keyboard focus");
            settle(() => selector.filtered[list.currentIndex].id === "stop", "service menu skips disabled start");
            input.keyClick(Qt.Key_Down);
            settle(() => selector.filtered[list.currentIndex].id === "disable", "service navigation skips enabled-on-login no-op");
            input.keyClick(Qt.Key_Up); input.keyClick(Qt.Key_Return);
        },
        () => {
            check(controller.confirmation.action === "lifecycle.stop", "service choice opens exact confirmation");
            settle(() => item("confirmation-cancel").item.activeFocus, "service confirmation focuses Cancel first");
            click("confirmation-submit");
            check(service.calls[service.calls.length - 1].action === "lifecycle.stop", "verified service action submitted once");
            service.settle(true, {});
            service.canControlService = false;
            service.lifecycle = {};
            controller.folderId = "a";
            service.currentActivity = {folderId: "a", action: "upload"};
            service.activityText = "Uploading nested/file.txt";
        },
        () => {
            check(item("activity-a").text.indexOf("Uploading") >= 0 && item("activity-a").tone === "success", "upload activity is visible and semantic");
            service.connection = {fresh: false};
            check(item("activity-a").text.indexOf("Last reported") === 0 && item("activity-a").tone === "muted", "stale activity never appears current");
            service.connection = {fresh: true};
            service.currentActivity = {folderId: "a", action: "removing"};
            check(item("activity-a").tone === "danger", "removing activity uses destructive semantics");
            service.activityText = ""; service.currentActivity = {};
            click("folder-trigger");
        },
        () => { edit("folder-search", "no-such-folder-xyz"); },
        () => {
            settle(() => item("folder-empty").visible && item("folder-empty").text.indexOf("No matches") === 0, "no-match menu explains recovery");
            input.mouseClick(window.contentItem, window.width - 20, 100, Qt.LeftButton);
        },
        () => {
            settle(() => controller.selector === "", "outside click dismisses production popup");
            settle(() => item("folder-trigger").item.activeFocus, "outside dismissal restores trigger focus");
            input.keyClick(Qt.Key_Tab);
            settle(() => !item("folder-trigger").item.activeFocus, "ordinary Tab advances native focus");
            click("settings");
        },
        () => {
            var toggle = item("settings-monochrome"), before = settings.draft.monochrome;
            toggle.focusControl(); input.keyClick(Qt.Key_Space);
            check(settings.draft.monochrome !== before, "native toggle edits settings by keyboard");
            input.keyClick(Qt.Key_J);
            settle(() => item("settings-probe").item.activeFocus, "directional navigation includes settings switch");
            click("cancel");
            controller.queries = Object.assign({}, controller.queries, {folder: ""});
            service.online = false;
            service.connection = {fresh: false, endpoint: "https://127.0.0.1:9443"};
            service.lastError = "TLS certificate verification failed";
        },
        () => {
            check(item("connection-error").visible && item("connection-error").text.indexOf("TLS") >= 0, "TLS failure is rendered");
            check(!item("add-folder").enabled && !item("folder-pause").enabled, "offline mutations are unavailable");
            check(item("tracked-totals").value.indexOf("last reported") >= 0, "offline totals remain explicitly stale");
            service.lastError = "Authentication failed";
            check(item("connection-error").text === "Authentication failed", "credential failure is rendered without secrets");
            service.online = true; service.connection = {fresh: true}; service.lastError = "";
            check(item("add-folder").enabled && !item("connection-error").visible, "recovery restores usable controls and clears errors");
            originalFolders = service.folders; service.folders = [];
            click("folder-trigger");
        },
        () => {
            settle(() => item("folder-empty").visible && item("folder-empty").text === "No choices available", "empty selector explains absence of choices");
            input.keyClick(Qt.Key_Return);
            check(controller.selector === "folder", "empty selector Enter cannot invent a target");
            input.keyClick(Qt.Key_Escape);
            service.folders = originalFolders;
        }
    ]
    Process {
        id: ioPreparation
        command: ["python3", "-c", "import os,sys; p=os.path.dirname(sys.argv[1]); os.makedirs(p,exist_ok=True); os.chmod(p,0o555)", settings.path]
        onExited: code => root.check(code === 0, "prepare disposable settings IO failure")
    }
    Process {
        id: ioRecovery
        command: ["python3", "-c", "import os,sys; os.chmod(os.path.dirname(sys.argv[1]),0o755)", settings.path]
        onExited: code => root.check(code === 0, "restore disposable settings directory")
    }
    Timer {
        id: steps
        interval: 70
        running: true
        repeat: false
        onTriggered: {
            window.requestActivate();
            if (ioPreparation.running || ioRecovery.running || settings.saving) {
                stalledTicks++;
                root.check(stalledTicks < 200, "settings IO did not settle");
                steps.restart(); return;
            }
            stalledTicks = 0;
            if (root.step < root.actions.length) {
                root.capture("step-" + root.step);
                root.actions[root.step]();
                root.step++;
                steps.restart();
                return;
            }
            console.log("[ok] production UI behavior " + fixtureHost.style.family + ": " + root.actions.length + " input stages");
            if (root.familyIndex === 0) {
                controller.presentationActive = false;
                root.presented = false;
                controller.tab = "folders";
                controller.more = false;
                controller.closeMenus();
                controller.folderId = "a";
                service.pendingDevices = [{id: root.requestId, name: "<b>plain text</b>", address: "tcp://pending"}];
                root.familyIndex = 1;
                root.step = 0;
                controller.presentationActive = true;
                root.presented = true;
                steps.restart();
            } else {
                console.log("[ok] native controls, forms, confirmations, picker, navigation and diagnostics executed in both families");
                Qt.quit();
            }
        }
    }
}
