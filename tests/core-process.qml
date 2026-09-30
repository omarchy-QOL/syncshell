import QtQuick
import Quickshell
import "../shared"

ShellRoot {
    id: root

    property int readyCount: 0
    property int completedRequests: 0
    property bool restartRequested: false
    property int handledGeneration: 0
    property bool versionFailurePassed: false
    property bool lineBoundPassed: false
    property bool duplicateResultPassed: false
    property bool pendingFailurePassed: false
    property bool crashCapPassed: false
    property bool manualRecoveryPassed: false
    readonly property string testPluginRoot: Quickshell.env("SYNCSHELL_TEST_PLUGIN_ROOT") || ""

    function fail(message) {
        console.error(message);
        core.terminate();
        crashProbe.terminate();
        Qt.exit(1);
    }

    function requestCompleted(ok, data, error) {
        if (!ok || error) {
            fail("mock request failed: " + JSON.stringify(error));
            return;
        }
        completedRequests++;
        if (completedRequests === 3) {
            restartRequested = true;
            if (!core.restart())
                fail("core restart was rejected");
        }
    }

    function handleSnapshot() {
        if (!core.protocolReady || core.revision < 1 || handledGeneration === core.generation)
            return;
        handledGeneration = core.generation;
        readyCount++;
        if (core.snapshot.connection.online !== true || core.snapshot.identity.deviceId !== "TEST-ID" || core.snapshot.folders.length !== 1) {
            fail("snapshot projection failed");
            return;
        }
        if (readyCount === 1) {
            core.configure({
                probeIntervalSeconds: 2
            }, requestCompleted);
            core.refresh(requestCompleted);
            core.action("folder.rescan", {
                folderId: "folder"
            }, requestCompleted);
        } else if (readyCount === 2 && restartRequested) {
            core.terminate();
            completionTimer.restart();
        }
    }

    CoreProcess {
        id: core
        pluginRoot: root.testPluginRoot

        onRevisionChanged: root.handleSnapshot()

        onProtocolFailed: function (message) {
            root.fail(message);
        }
    }

    CoreProcess {
        id: duplicateResultProbe
        pluginRoot: root.testPluginRoot
        desiredRunning: false
        onProtocolFailed: function (message) {
            root.duplicateResultPassed = message.indexOf("duplicate or unknown") >= 0;
        }
    }

    CoreProcess {
        id: crashProbe
        pluginRoot: root.testPluginRoot
        startupArguments: ["--test-exit-on-request"]
        onRevisionChanged: {
            if (!protocolReady || revision < 1)
                return;
            if (!root.crashCapPassed) {
                if (!refresh(function (ok, data, error) {
                    if (ok || !error || error.code !== "core_unavailable")
                        root.fail("pending request did not receive core-unavailable failure");
                    root.pendingFailurePassed = true;
                }))
                    root.fail("pending request was rejected");
            } else {
                root.manualRecoveryPassed = true;
                terminate();
            }
        }
    }

    CoreProcess {
        id: versionProbe
        pluginRoot: root.testPluginRoot
        desiredRunning: false
        onProtocolFailed: function (message) {
            root.versionFailurePassed = message.indexOf("protocol major") >= 0;
        }
    }

    CoreProcess {
        id: lineBoundProbe
        pluginRoot: root.testPluginRoot
        desiredRunning: false
        onProtocolFailed: function (message) {
            root.lineBoundPassed = message.indexOf("line bound") >= 0;
        }
    }

    Timer {
        id: completionTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (!root.crashCapPassed) {
                if (crashProbe.desiredRunning) {
                    restart();
                    return;
                }
                if (crashProbe.generation !== 4 || crashProbe.restartAttempts !== 3) {
                    root.fail("crashes did not stop after three automatic retries");
                    return;
                }
                root.crashCapPassed = true;
                crashProbe.startupArguments = [];
                crashProbe.restart();
            }
            if (core.running || !root.pendingFailurePassed || crashProbe.running || !root.manualRecoveryPassed) {
                restart();
                return;
            }
            if (root.completedRequests !== 3 || root.readyCount !== 2 || !root.versionFailurePassed || !root.lineBoundPassed || !root.pendingFailurePassed || !root.duplicateResultPassed) {
                root.fail("core process lifecycle did not complete");
                return;
            }
            console.log("core process tests passed");
            Qt.exit(0);
        }
    }

    Timer {
        interval: 1
        running: true
        repeat: false
        onTriggered: {
            versionProbe.handleLine('{"v":3,"type":"hello"}');
            lineBoundProbe.handleLine("x".repeat(lineBoundProbe.maxLineLength + 1));
            var hello = '{"v":2,"type":"hello",' + '"build":{"version":"test"}}';
            var result = '{"v":2,"type":"result","id":"1","ok":true}';
            duplicateResultProbe.handleLine(hello);
            duplicateResultProbe._pending = ({
                    "1": null
                });
            duplicateResultProbe.handleLine(result);
            duplicateResultProbe.handleLine(result);
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: false
        onTriggered: root.fail("core process test timed out")
    }
}
