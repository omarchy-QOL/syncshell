//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "syncshell/hosts/illogical-impulse" as Adapter
import "syncshell/hosts/illogical-impulse/controllers" as Controllers
import "syncshell/hosts/illogical-impulse/ui" as UI
import "syncshell/hosts/illogical-impulse/ui/ii" as Material
import "syncshell/hosts/illogical-impulse/ui/waffle" as Waffle

ShellRoot {
    id: root
    readonly property string work: Quickshell.env("SYNCSHELL_FIXTURE_WORK")
    readonly property string peerId: Array(8).fill("BBBBBBB").join("-")
    readonly property string pendingId: Array(8).fill("CCCCCCC").join("-")
    readonly property string newId: Array(8).fill("DDDDDDD").join("-")
    property int step: 0
    property int waited: 0
    Material.NativeStyle { id: material }
    Waffle.NativeStyle { id: waffle }
    Adapter.IllogicalService {
        id: service
        active: true
        configPath: Quickshell.env("SYNCSHELL_FIXTURE_CONFIG")
        probeIntervalSeconds: 1
        lifecyclePolicy: ({})
    }
    Controllers.PanelController { id: controller; service: service }
    Controllers.SettingsController { id: settings; service: service }
    Controllers.ThemePaletteController { id: palette; service: service; settings: settings; palette: fixtureHost.style.palette }
    QtObject {
        id: fixtureHost
        property var style: Quickshell.env("SYNCSHELL_FIXTURE_FAMILY") === "waffle" ? waffle : material
        property var service: service
        property var controller: controller
        property var settings: settings
        property var paletteController: palette
        function close() { controller.handleEscape(); }
    }
    Window {
        id: window
        visible: true
        width: 900; height: 900
        color: fixtureHost.style.background
        UI.SyncshellPanelPopup { id: main; host: fixtureHost; x: 12; y: 12; width: 430; height: 870 }
        Loader {
            id: side
            x: 460; y: 12; width: 420; height: 870
            active: controller.formVisible || controller.confirmationVisible || settings.opened
            sourceComponent: UI.SyncshellPanelPopup { host: fixtureHost; side: true }
        }
        TestCase { id: input; when: false }
    }
    function check(value, message) {
        if (!value) {
            input.grabImage(window.contentItem).save(work + "/failure.png");
            console.error("[fail] " + fixtureHost.style.family + " core stage " + step + ": " + message
                + " service=" + service.lastError + " controller=" + controller.error + " settings=" + settings.error
                + " view=" + controller.view + " draft=" + JSON.stringify(controller.draft)
                + " confirmation=" + JSON.stringify(controller.confirmation));
            Qt.exit(1);
            throw Error(message);
        }
    }
    function item(name) {
        var value = input.findChild(window.contentItem, name);
        check(value !== null, "production control " + name);
        return value;
    }
    function click(name) {
        input.wait(180);
        var value = item(name);
        check(value.enabled, name + " enabled");
        if (typeof value.focusControl === "function") value.focusControl();
        main.reveal(value);
        if (side.item) side.item.reveal(value);
        input.wait(250);
        // Snapshot refresh may temporarily disable actions while focus scrolls.
        for (var attempt = 0; !value.enabled && attempt < 100; attempt++) input.wait(20);
        check(value.enabled, name + " enabled at mouse delivery");
        var control = value.item || value;
        input.mouseClick(control, control.width / 2, control.height / 2, Qt.LeftButton);
    }
    function edit(name, text) {
        var value = item(name);
        value.focusControl();
        input.wait(30);
        input.keyClick(Qt.Key_A, Qt.ControlModifier);
        check(value.item.selectedText.length === value.item.text.length, "editor selection " + name);
        for (var index = 0; index < text.length; index++) input.keyClick(text[index]);
    }
    function choose(key, query) {
        click(key + "-trigger");
        input.wait(180);
        edit(key + "-search", query);
        input.keyClick(Qt.Key_Return);
        input.wait(180);
    }
    function confirm() {
        check(item("confirmation-cancel").item.activeFocus, "Cancel is focused before mutation");
        click("confirmation-submit");
    }
    readonly property var actions: [
        () => { check(service.folder("folder") !== null, "initial snapshot"); click("refresh"); },
        () => { check((service.folder("folder").status.errors || []).length === 0, "refresh rechecked errors"); click("folder-pause"); },
        () => confirm(),
        () => { check(service.folder("folder").paused, "folder paused"); click("folder-pause"); },
        () => confirm(),
        () => { check(!service.folder("folder").paused, "folder resumed"); click("rescan"); },
        () => { check(service.actionNotice.indexOf("Rescan complete") >= 0, "scan settled"); click("add-folder"); },
        () => {
            check(controller.draft.folderId === "generated1", "Go-generated ID reached form");
            edit("folder-id", "newfolder");
            edit("folder-path", work + "/data/nested");
            click("save-folder");
        },
        () => {
            check(controller.error.indexOf("overlap") >= 0, "Go overlap validation preserved draft");
            edit("folder-path", work + "/created");
            click("save-folder");
        },
        () => {
            check(controller.confirmation && controller.confirmation.args.createDirectory, "missing path requires explicit confirmation");
            confirm();
        },
        () => { check(service.folder("newfolder").path === work + "/created", "Go created and configured requested directory"); click("share-folder"); },
        () => { choose("sharing", peerId); input.keyClick(Qt.Key_Escape); click("save-sharing"); },
        () => {
            check(service.remoteDeviceIdsForFolder("newfolder").indexOf(peerId) >= 0, "folder sharing reached Syncthing");
            click("tab-devices"); click("folders");
        },
        () => { choose("device-folders", "newfolder"); input.keyClick(Qt.Key_Escape); click("save-sharing"); },
        () => { check(controller.confirmation.args.folderIds.join() === "newfolder", "exact reverse sharing target"); confirm(); },
        () => { check(service.remoteDeviceIdsForFolder("newfolder").length === 0, "reverse sharing removed only remote peer"); click("add-device"); },
        () => { edit("device-id", newId.toLowerCase()); edit("device-name", "New peer"); click("save-device"); },
        () => { check(service.device(newId).name === "New peer", "normalized ID and name reached Go"); click("device-pause"); },
        () => confirm(),
        () => { check(service.device(newId).paused, "device paused"); click("device-pause"); },
        () => confirm(),
        () => { check(!service.device(newId).paused, "device resumed"); click("remove-device"); },
        () => confirm(),
        () => { check(service.device(newId) === null, "device removed"); choose("pending-devices", pendingId); click("accept-pending-device"); },
        () => { check(controller.draft.deviceId === pendingId, "pending identity frozen in accept form"); click("save-device"); },
        () => { check(service.device(pendingId) !== null, "pending device accepted"); click("dismiss-pending-device"); },
        () => confirm(),
        () => { check(service.pendingDevices.length === 0, "remaining device request dismissed"); choose("pending-folders", "offered"); click("accept-pending-folder"); },
        () => { check(controller.draft.pendingDeviceId === peerId, "offered folder keeps sender"); edit("folder-path", work + "/offered"); click("save-folder"); },
        () => {
            check(service.folder("offered") !== null, "offered folder accepted");
            choose("pending-folders", pendingId); click("dismiss-pending-folder");
        },
        () => { check(controller.confirmation.args.pendingDeviceId === pendingId, "duplicate folder offers preserve sender identity"); confirm(); },
        () => {
            check(service.pendingFolderOffers().length === 1 && service.pendingFolderOffers()[0].deviceId === peerId, "only chosen sender dismissed");
            click("settings");
        },
        () => { choose("webui-profile", "Modern"); click("save-settings"); },
        () => { check(settings.error !== "" && settings.hasDraft, "profile backend failure retains draft"); click("reapply-profile"); },
        () => { check(service.webUi.theme === "syncshell-illogical-impulse-modern" && !settings.hasDraft, "profile retry saved preference and actual theme"); click("settings"); },
        () => { check(item("actual-webui-theme").value === service.webUi.theme, "actual selected theme rendered"); click("cleanup-profiles"); },
        () => confirm(),
        () => {
            check(service.webUi.theme === "default" && settings.values.webUi === "default", "profile cleanup settled and persisted");
            click("tab-folders"); choose("folder", "Fixture"); click("folder-pause");
        },
        () => confirm(),
        () => { check(service.folder("folder").paused, "forget precondition verified"); click("forget"); },
        () => confirm(),
        () => { check(service.folder("folder") === null, "folder forgotten without file deletion"); service.active = false; }
    ]
    Timer {
        id: steps
        interval: 100
        running: true
        onTriggered: {
            root.waited++;
            root.check(root.waited < 600, "timeout awaiting stage settlement");
            if (root.step === root.actions.length) {
                if (service.core.running) { steps.restart(); return; }
                console.log("[ok] real Go child: " + fixtureHost.style.family + " completed " + root.actions.length + " production input stages");
                Qt.quit();
                return;
            }
            if (!service.online || service.busy || service.refreshing || settings.saving) { steps.restart(); return; }
            window.requestActivate();
            console.log("stage", root.step);
            root.actions[root.step]();
            root.step++;
            steps.restart();
        }
    }
}
