import QtQuick
import Quickshell
import "../hosts/omarchy/ui"

ShellRoot {
    id: root

    property int activations: 0
    property real idleWidth: 0
    property int holdMilliseconds: Math.max(120, Number(Quickshell.env("SYNCSHELL_BUSY_HOLD_MS") || 120))

    VisualPause { id: inspection }

    FloatingWindow {
        visible: true
        implicitWidth: 520
        implicitHeight: 150
        title: "Syncshell rescan lifecycle"

        Rectangle {
            anchors.fill: parent
            color: "#181825"

            Column {
                anchors.centerIn: parent
                spacing: 16

                BusyButton {
                    id: button
                    text: "RESCAN"
                    busyText: "RESCANNING A LONG FOLDER LABEL"
                    iconText: "󰑐"
                    focusable: true
                    foreground: "#cdd6f4"
                    busyForeground: "#ebcb8b"
                    onClicked: root.activations++
                }

                BusyButton {
                    id: pulseButton
                    text: "Refresh Sync.status"
                    busyText: "Rechecking Syncthing"
                    iconText: "\uf21e"
                    busy: button.busy
                    pulseBusyIcon: true
                    foreground: "#cdd6f4"
                    busyForeground: "#ebcb8b"
                }
            }
        }
    }

    function compare(actual, expected, name) {
        if (JSON.stringify(actual) !== JSON.stringify(expected)) {
            throw new Error(name + ": expected " + JSON.stringify(expected) + ", got " + JSON.stringify(actual));
        }
    }

    function startTests() {
        idleWidth = button.implicitWidth;
        compare(button.interactive, true, "idle button interactive");
        compare(button.inputTargetEnabled, true, "idle input target enabled");
        compare(button.activate(), true, "idle activation accepted");
        compare(activations, 1, "idle activation emitted");
        button.busy = true;
        busyTimer.start();
    }

    function checkBusy() {
        compare(button.implicitWidth > root.idleWidth, true, "long busy label expands button");
        compare(button.interactive, false, "busy button not interactive");
        compare(button.inputTargetEnabled, false, "busy input target removed");
        compare(button.busyIconRotation > 0, true, "busy icon rotates");
        compare(pulseButton.busyIconRotation, 0, "pulse icon does not rotate");
        compare(pulseButton.busyIconScale > 1, true, "pulse icon grows");
        compare(button.activate(), false, "busy activation rejected");
        compare(activations, 1, "busy activation not emitted");
    }

    function checkUnavailable() {
        button.busy = false;
        button.canActivate = false;
        inspection.pause("unavailable button", function () {
            root.finishUnavailable();
        });
    }

    function finishUnavailable() {
        compare(button.interactive, false, "unavailable button not interactive");
        compare(button.inputTargetEnabled, false, "unavailable input target removed");
        compare(button.activate(), false, "unavailable activation rejected");
        compare(activations, 1, "unavailable activation not emitted");

        button.canActivate = true;
        button.enabled = false;
        inspection.pause("disabled button", function () {
            root.checkDisabled();
            console.log("busy button tests passed");
            Qt.exit(0);
        });
    }

    function checkDisabled() {
        compare(button.interactive, false, "disabled button not interactive");
        compare(button.inputTargetEnabled, false, "disabled input target removed");
        compare(button.activate(), false, "disabled activation rejected");
        compare(activations, 1, "disabled activation not emitted");
    }

    Timer {
        interval: 1
        running: true
        repeat: false
        onTriggered: {
            try {
                inspection.pause("idle button", function () { root.startTests(); });
            } catch (error) {
                console.error(error);
                Qt.exit(1);
            }
        }
    }

    Timer {
        id: busyTimer
        interval: root.holdMilliseconds
        repeat: false
        onTriggered: {
            try {
                root.checkBusy();
                inspection.pause("busy label with rotating and pulsing icons",
                                 function () { root.checkUnavailable(); });
            } catch (error) {
                console.error(error);
                Qt.exit(1);
            }
        }
    }
}
