import QtQuick
import QtTest
import "../../hosts/illogical-impulse/controllers" as Controllers

TestCase {
    name: "IllogicalThemePalette"
    QtObject {
        id: service
        property bool online: true
        property bool busy: false
        property var webUi: ({theme: "default"})
        property var calls: []
        signal actionFinished(string action, bool ok, var data, var failure)
        function runAction(action, args) {
            calls = calls.concat([{action: action, args: args}]);
            return true;
        }
    }
    QtObject { id: settings; property var values: ({webUi: "default"}) }
    Controllers.ThemePaletteController { id: palette; service: service; settings: settings }
    function init() {
        settings.values = {webUi: "default"};
        service.webUi = {theme: "default"};
        service.online = true;
        service.busy = false;
        palette.applied = "";
        palette.failed = "";
        palette.requested = "";
        palette.palette = {mode: "dark", accent: "#112233"};
        service.calls = [];
    }
    function selectThemed() {
        settings.values = {webUi: "themed"};
        service.webUi = {theme: "syncshell-illogical-impulse-themed"};
    }
    function test_only_owned_selected_profile_updates() {
        settings.values = {webUi: "modern"};
        wait(300);
        compare(service.calls.length, 0);
        settings.values = {webUi: "themed"};
        service.webUi = {theme: "another-adapter"};
        wait(300);
        compare(service.calls.length, 0);
        selectThemed();
        wait(300);
        compare(service.calls.length, 1);
        compare(service.calls[0].action, "webui.refresh-profile");
        service.actionFinished("webui.refresh-profile", true, {}, null);
        service.busy = true;
        service.busy = false;
        wait(300);
        compare(service.calls.length, 1);
    }
    function test_family_palette_debounces_and_offline_recovers() {
        service.online = false;
        selectThemed();
        palette.palette = {mode: "light", accent: "#445566"};
        wait(300);
        compare(service.calls.length, 0);
        service.online = true;
        palette.palette = {mode: "light", accent: "#778899"};
        wait(300);
        compare(service.calls.length, 1);
        compare(service.calls[0].args.palette.accent, "#778899");
    }
    function test_explicit_retry_without_claiming_another_theme() {
        selectThemed();
        wait(300);
        service.actionFinished("webui.refresh-profile", false, {}, {message: "Palette IO failed"});
        compare(palette.error, "Palette IO failed");
        verify(palette.retry());
        compare(service.calls.length, 2);
        service.actionFinished("webui.refresh-profile", true, {}, null);
        compare(palette.error, "");
        service.webUi = {theme: "another-adapter"};
        verify(!palette.retry());
        compare(service.calls.length, 2);
    }
    function test_failed_palette_does_not_loop() {
        selectThemed();
        wait(300);
        service.actionFinished("webui.refresh-profile", false, {}, null);
        service.busy = true;
        service.busy = false;
        wait(300);
        compare(service.calls.length, 1);
    }
}
