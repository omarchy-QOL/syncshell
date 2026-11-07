import QtQuick
import Quickshell
import "../hosts/omarchy"
import "../hosts/omarchy/Bridge.js" as Bridge

ShellRoot {
    id: root

    property QtObject direct: QtObject {
        function setRefreshInterval(seconds) {}
    }

    component FakeBar: QtObject {
        property var service: null
        property color foreground: "white"
        property color urgent: "red"
        property string fontFamily: "sans"
        readonly property var shell: ({
                serviceFor: () => service
            })
    }

    function check(value, message) {
        if (!value) {
            console.error(message);
            service.core.terminate();
            Qt.exit(1);
            throw new Error(message);
        }
    }

    OmarchyService {
        id: service
    }

    OmarchyPanel {
        id: replacementBarPanel
        moduleName: "test.replacement"
        bar: FakeBar {}
    }

    OmarchyPanel {
        id: nativeBarPanel
        moduleName: "test.native"
        bar: FakeBar {
            service: root.direct
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: {
            root.check(replacementBarPanel.syncthing === service, "replacement bar panel did not find the published service");
            root.check(nativeBarPanel.syncthing === root.direct, "native bar lookup must win over the bridge");
            Bridge.clear(root.direct);
            root.check(Bridge.current() === service, "retired service cleared its replacement");
            service.core.terminate();
            console.log("replacement bar tests passed");
            Qt.quit();
        }
    }
}
