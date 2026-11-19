import QtQuick
import QtTest
import "../../hosts/caelestia/controllers"

TestCase {
    id: test
    name: "CaelestiaSettingsValidation"
    SettingsController {
        id: settings
    }
    function values() {
        return {
            schemaVersion: 1,
            icon: "sync",
            probeSeconds: 15,
            refreshSeconds: 60,
            webUiStyle: "default",
            lifecycleAuthorized: false,
            lifecycleUnit: "syncthing.service",
            lifecycleConfig: "/private/config.xml"
        };
    }
    function test_intervals_match_the_core_contract() {
        for (var seconds of [1, 3600]) {
            var value = values();
            value.probeSeconds = seconds;
            compare(settings.validate(value), "");
        }
        for (var seconds of [60, 3600]) {
            var value = values();
            value.refreshSeconds = seconds;
            compare(settings.validate(value), "");
        }
        for (var seconds of [0, 59, 3601, 60.5]) {
            var value = values();
            value.refreshSeconds = seconds;
            verify(settings.validate(value).includes("Refresh interval"));
        }
    }
    function test_service_authorization_rejects_patterns() {
        for (var unit of ["syncthing*", "syncthing.service other.service", "syncthing", ""]) {
            var value = values();
            value.lifecycleAuthorized = true;
            value.lifecycleUnit = unit;
            verify(settings.validate(value).includes("exact unit"));
        }
        var value = values();
        value.lifecycleAuthorized = true;
        compare(settings.validate(value), "");
    }
    function test_replacement_does_not_keep_a_stale_settings_object() {
        var previous = values();
        settings.settings = previous;
        var current = values();
        current.probeSeconds = 31;
        settings.settings = current;
        previous.probeSeconds = 200;
        compare(settings.settings.probeSeconds, 31);
        verify(settings.valid);
        current = values();
        current.schemaVersion = 99;
        settings.settings = current;
        verify(!settings.valid);
    }
}
