//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QS_NO_RELOAD_POPUP=1
import QtQuick
import Quickshell
import qs.modules.common
import qs.syncshell as Syncshell

ShellRoot {
    id: root
    property int waited: 0
    property bool awaitingReload: false
    PersistentProperties { id: history; reloadableId: "syncshell-owner-test"; property int step: 0 }
    Loader { id: owner; active: true; sourceComponent: Syncshell.IllogicalHost {} }
    function check(value, message) {
        if (!value) { console.error("[fail] " + message); Qt.exit(1); }
    }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (root.awaitingReload) return;
            root.waited++;
            if (root.waited > 100) { root.check(false, "owner lifetime timeout at " + history.step); return; }
            var host = owner.item;
            if (history.step === 9) {
                root.check(Syncshell.Registry.owner === null, "registry released after teardown");
                console.log("[ok] one owner preserves drafts across families and stops its worker on disable/reload/teardown");
                Qt.quit();
                return;
            }
            if (!host || !host.service.core.protocolReady) {
                if (history.step === 6 && host && !host.service.core.running) {
                    host.enabled = true;
                    history.step = 7;
                }
                return;
            }
            if (history.step === 0) {
                host.controller.addFolder(null);
                host.controller.edit("path", "/tmp/retained-draft");
                history.step = 1;
                Config.options.panelFamily = "waffle";
            } else if (history.step === 1) {
                root.check(host.controller.draft.path === "/tmp/retained-draft", "family switch retained draft");
                root.check(host.service.core.generation === 1, "family switch did not start worker");
                host.close();
                host.controller.reopen();
                Config.options.panelFamily = "ii";
                history.step = 2;
            } else if (history.step === 2) {
                root.check(host.controller.draft.path === "/tmp/retained-draft", "popup close retained draft");
                host.controller.ask("folder.add-existing", {folderId: "retained", path: "/tmp/frozen-target"}, "Create?", "Frozen");
                host.close();
                Config.options.panelFamily = "waffle";
                history.step = 3;
            } else if (history.step === 3) {
                root.check(host.controller.confirmation.args.path === "/tmp/frozen-target", "family change retains immutable confirmation");
                root.check(host.service.core.generation === 1, "confirmation has one worker owner");
                host.controller.reopen();
                root.check(host.controller.confirm(false), "retained confirmation submitted once");
                Config.options.panelFamily = "ii";
                history.step = 4;
            } else if (history.step === 4) {
                root.check(host.controller.pending, "delayed operation remains in flight across family switch");
                root.check(!host.controller.confirm(false), "repeat confirmation does not replay");
                host.controller.edit("path", "/tmp/blocked");
                root.check(host.controller.draft.path === "/tmp/retained-draft", "pending draft remains frozen");
                root.check(host.controller.submitted.args.path === "/tmp/frozen-target", "pending target remains frozen");
                host.close();
                Config.options.panelFamily = "waffle";
                history.step = 5;
            } else if (history.step === 5) {
                if (host.controller.pending) return;
                root.check(host.controller.view === "", "delayed result settled original generation");
                root.check(host.service.core.generation === 1, "family transitions did not restart worker");
                host.enabled = false;
                history.step = 6;
            } else if (history.step === 7) {
                root.check(host.service.core.generation === 2, "disable/enable starts one new generation");
                history.step = 8;
                root.awaitingReload = true;
                Quickshell.reload(false);
            } else if (history.step === 8) {
                root.check(host.service.core.generation === 1, "reload owns its new core generation");
                owner.active = false;
                history.step = 9;
            }
        }
    }
}
