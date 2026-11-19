pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Ui
import "UiConstants.js" as UiConstants

Column {
    id: root

    property var controller
    property Item keyboardCursor: null
    property Timer refreshFeedbackTimer: Timer {
        interval: UiConstants.REFRESH_FEEDBACK_MIN_MS
        onTriggered: Qt.callLater(refreshStatusButton.finishRefreshFeedback)
    }
    readonly property var keyboardRows: [[webUiButton], [rescanAllButton, refreshStatusButton, settingsButton]]

    signal actionHovered(Item action)

    function activateRescanAll() {
        rescanAllButton.activate();
    }

    spacing: Style.space(12)

    PanelSeparator {
        foreground: root.controller.foreground
    }

    Row {
        spacing: Style.space(6)

        Button {
            id: webUiButton
            text: "Web UI"
            height: Style.spacing.controlHeight
            bordered: true
            foreground: root.controller.foreground
            fontFamily: root.controller.fontFamily
            fontSize: Style.font.body
            horizontalPadding: Style.space(6)
            verticalPadding: Style.space(4)
            enabled: root.controller.syncthing !== null && root.controller.syncthing.online
            hasCursor: root.keyboardCursor === webUiButton
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(webUiButton);
            }
            onClicked: root.controller.openWebUi()
        }

        Repeater {
            model: ["TUI", "GUI"]

            SharedWidgetBusyButton {
                required property string modelData
                text: modelData
                height: Style.spacing.controlHeight
                tooltipText: "To be added soon."
                canActivate: false
                bordered: true
                foreground: root.controller.foreground
                disabledForeground: root.controller.dim
                fontFamily: root.controller.fontFamily
                fontSize: Style.font.body
                horizontalPadding: Style.space(6)
                verticalPadding: Style.space(4)
            }
        }
    }

    Row {
        spacing: Style.spacing.sm

        SharedWidgetBusyButton {
            id: rescanAllButton
            height: Style.spacing.controlHeight
            iconText: "󰑐"
            text: "Rescan all folders"
            busyText: "Rescanning..."
            tooltipText: "Rescan all folders for local changes."
            busy: root.controller.syncthing && root.controller.syncthing.folderMutationAction === "rescan-all"
            bordered: true
            foreground: root.controller.foreground
            busyForeground: root.controller.warning
            fontFamily: root.controller.fontFamily
            fontSize: Style.font.body
            iconSize: Style.font.body
            horizontalPadding: Style.space(5)
            verticalPadding: Style.space(4)
            canActivate: root.controller.syncthing && root.controller.syncthing.online && root.controller.rescannableFolderCount > 0 && !root.controller.syncthing.refreshing && !root.controller.syncthing.folderMutationBusy
            hasCursor: root.keyboardCursor === rescanAllButton
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(rescanAllButton);
            }
            onClicked: root.controller.syncthing.rescanAllFolders()
        }

        SharedWidgetBusyButton {
            id: refreshStatusButton
            property bool refreshRequested: false
            property bool refreshSucceeded: false

            function finishRefreshFeedback() {
                if (!refreshSucceeded || refreshRequested || root.refreshFeedbackTimer.running)
                    return;
                refreshSucceeded = false;
                root.controller.showNotice("Syncthing status refreshed", UiConstants.BRIEF_NOTICE_VISIBLE_MS);
            }

            iconText: "\uf21e"
            height: Style.spacing.controlHeight
            text: "Refresh Sync.status"
            busyText: "Rechecking Syncthing"
            pulseBusyIcon: true
            tooltipText: "Request latest Syncthing state.\n" + "Active folders with current errors\n" + "rescanned and errors rechecked."
            bordered: true
            foreground: root.controller.foreground
            busyForeground: root.controller.warning
            fontFamily: root.controller.fontFamily
            fontSize: Style.font.body
            iconSize: Style.font.body
            horizontalPadding: Style.space(5)
            verticalPadding: Style.space(4)
            busy: refreshRequested || root.refreshFeedbackTimer.running
            canActivate: root.controller.syncthing && root.controller.syncthing.online && root.controller.syncthing.canRefresh && !root.refreshFeedbackTimer.running
            hasCursor: root.keyboardCursor === refreshStatusButton
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(refreshStatusButton);
            }
            onClicked: {
                refreshSucceeded = false;
                refreshRequested = root.controller.syncthing.refresh(true, function (ok) {
                    refreshStatusButton.refreshSucceeded = ok;
                    refreshStatusButton.finishRefreshFeedback();
                });
                if (refreshRequested)
                    root.refreshFeedbackTimer.restart();
            }

            Connections {
                target: root.controller.syncthing
                function onRefreshingChanged() {
                    if (!root.controller.syncthing.refreshing) {
                        refreshStatusButton.refreshRequested = false;
                        refreshStatusButton.finishRefreshFeedback();
                    }
                }
            }
        }

        SharedWidgetTooltipButton {
            id: settingsButton
            width: Style.spacing.controlHeight
            height: Style.spacing.controlHeight
            iconText: "\uf013"
            helpText: "Settings"
            bordered: true
            foreground: root.controller.foreground
            fontFamily: root.controller.fontFamily
            iconSize: Style.font.body
            enabled: root.controller.syncthing !== null
            hasCursor: root.keyboardCursor === settingsButton
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(settingsButton);
            }
            onClicked: root.controller.openSettingsMenu()
        }
    }
}
