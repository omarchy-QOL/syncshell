import QtQuick
import QtTest
import "../../hosts/dankmaterialshell/controllers"

TestCase {
    id: test
    name: "DmsSettingsReplacement"
    property var settings
    Component {
        id: factory
        SettingsController {}
    }
    function stored(path) {
        return {
            syncshell: {
                schema: 1,
                owner: "omarchy-QOL/syncshell",
                configPath: path
            }
        };
    }
    function init() {
        settings = factory.createObject(test, {
            pluginData: stored("/first/config.xml")
        });
    }
    function cleanup() {
        settings.destroy();
    }
    function test_replacing_plugin_data_rebinds_values() {
        verify(settings.valid);
        compare(settings.values.configPath, "/first/config.xml");
        var previous = settings.pluginData;
        settings.pluginData = stored("/second/config.xml");
        compare(settings.values.configPath, "/second/config.xml");
        previous.syncshell.configPath = "/stale/config.xml";
        compare(settings.values.configPath, "/second/config.xml");
        settings.destroy();
        settings = factory.createObject(test, {
            pluginData: stored("/second/config.xml")
        });
        compare(settings.values.configPath, "/second/config.xml");
    }
    function test_invalid_replacement_revokes_settings_validity() {
        settings.pluginData = {
            syncshell: {
                schema: 99,
                owner: "another/plugin"
            }
        };
        verify(!settings.valid);
        verify(settings.validationError.length > 0);
        compare(settings.values.lifecycleAuthorized, false);
        settings.pluginData = stored("/recovered/config.xml");
        verify(settings.valid);
        compare(settings.values.configPath, "/recovered/config.xml");
    }
}
