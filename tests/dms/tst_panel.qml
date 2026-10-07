import QtQuick
import QtTest
import "../../hosts/dankmaterialshell/controllers"

TestCase {
    id: test
    name: "DmsPanelBehavior"
    property var controller
    QtObject {
        id: backend
        property var folders: []
        property var devices: []
        property bool online: true
        property var connection: ({
                fresh: true
            })
        property bool busy: false
        property bool refreshing: false
        property bool canControlService: true
        property var lifecycle: ({
                active: false,
                enabled: false
            })
        property var sent: null
        property string actionError: ""
        signal actionFinished(string action, bool ok, var data, var error)
        function remoteDevices() {
            return devices;
        }
        function shareableDevices() {
            return devices;
        }
        function folder(id) {
            return null;
        }
        function device(id) {
            return null;
        }
        function runAction(action, args) {
            sent = {
                action: action,
                args: args
            };
            busy = true;
            return true;
        }
    }
    Component {
        id: factory
        PanelController {
            service: backend
        }
    }
    function init() {
        backend.busy = false;
        backend.sent = null;
        backend.canControlService = true;
        backend.lifecycle = {
            active: false,
            enabled: false
        };
        controller = factory.createObject(test);
    }
    function cleanup() {
        controller.destroy();
    }
    function test_runtime_toggle_preserves_autostart() {
        for (var active of [false, true]) {
            for (var enabled of [false, true]) {
                backend.lifecycle = {
                    active: active,
                    enabled: enabled
                };
                verify(controller.requestServiceToggle(null));
                compare(controller.confirmation.action, active ? "lifecycle.stop" : "lifecycle.start");
                verify(controller.confirm());
                compare(backend.sent.action, active ? "lifecycle.stop" : "lifecycle.start");
                compare(backend.lifecycle.enabled, enabled);
                backend.busy = false;
                backend.actionFinished(backend.sent.action, true, {}, null);
            }
        }
    }
    function test_unauthorized_busy_and_nested_actions_are_blocked() {
        backend.canControlService = false;
        verify(!controller.requestServiceToggle(null));
        backend.canControlService = true;
        backend.busy = true;
        verify(!controller.requestServiceToggle(null));
        backend.busy = false;
        controller.begin("add-device", null, null);
        verify(!controller.requestServiceToggle(null));
        controller.closeForm();
        controller.requestConfirmation("device.remove", {
            id: "one"
        }, null);
        verify(!controller.requestServiceToggle(null));
        compare(controller.confirmation.action, "device.remove");
        compare(backend.sent, null);
    }
}
