import QtQuick
import Quickshell

QtObject {
    id: root

    readonly property int milliseconds: Number(Quickshell.env("SYNCSHELL_TEST_PAUSE_MS") || 0)
    property var continuation
    property Timer delay: Timer {
        interval: root.milliseconds
        onTriggered: {
            var next = root.continuation;
            root.continuation = null;
            try {
                next();
            } catch (error) {
                console.error(error);
                Qt.exit(1);
            }
        }
    }

    function pause(label, next) {
        if (milliseconds === 0 || !label) {
            next();
            return;
        }
        console.log("[view " + milliseconds + "ms] " + label);
        continuation = next;
        delay.restart();
    }
}
