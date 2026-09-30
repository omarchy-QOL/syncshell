import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Column {
    id: root

    property var controller
    required property Item cardAnchor
    property var syncthing
    property color foreground: Color.foreground
    property color dim: Qt.darker(foreground, 1.5)
    property color urgent: Color.urgent
    required property color warning
    required property color success
    property string fontFamily: Style.font.family
    property Item keyboardCursor: null

    property string selectedDeviceId: ""
    property string selectedPendingId: ""
    property bool addOpen: false
    property bool acceptOpen: false
    property bool foldersOpen: false
    property bool submitting: false

    readonly property var remoteRows: controller.remoteDeviceRows()
    readonly property var pendingRows: controller.pendingDeviceRows()
    readonly property var selectedDevice: rowById(remoteRows, selectedDeviceId)
    readonly property var selectedPending: rowById(pendingRows, selectedPendingId)
    readonly property bool popupOpen: deviceSelector.popupOpen || pendingSelector.popupOpen || addForm.popupOpen || foldersForm.popupOpen
    readonly property var keyboardRows: {
        var rows = [[deviceSelector, addDeviceButton, deviceFoldersButton, removeDeviceButton]];
        if (deviceCard.visible)
            rows = rows.concat(deviceCard.keyboardRows);
        if (pendingSelector.visible)
            rows.push([pendingSelector, acceptDeviceButton, dismissDeviceButton]);
        return rows;
    }

    signal actionHovered(Item action)

    function rowById(rows, id) {
        for (var i = 0; i < rows.length; i++) {
            if (String(rows[i].id || "") === String(id || ""))
                return rows[i];
        }
        return null;
    }

    function ensureSelections() {
        if (!rowById(remoteRows, selectedDeviceId))
            selectedDeviceId = remoteRows.length > 0 ? remoteRows[0].id : "";
        if (!rowById(pendingRows, selectedPendingId))
            selectedPendingId = pendingRows.length > 0 ? pendingRows[0].id : "";
    }

    function deviceState(device) {
        if (device && device.paused)
            return "PAUSED";
        return device && device.connected ? "CONNECTED" : "DISCONNECTED";
    }

    function deviceStateColor(device) {
        if (device && device.paused)
            return warning;
        return device && device.connected ? success : Color.muted;
    }

    function deviceStateHelp(device) {
        var state = deviceState(device);
        if (state === "PAUSED")
            return "PAUSED · Connections disabled";
        if (state === "CONNECTED")
            return "CONNECTED · Available";
        return "DISCONNECTED";
    }

    function deviceOptions() {
        var options = [];
        for (var i = 0; i < remoteRows.length; i++) {
            var device = remoteRows[i];
            options.push({
                value: device.id,
                label: device.name,
                trailingText: "(" + device.folderIds.length + " folder" + (device.folderIds.length === 1 ? "" : "s") + ")",
                statusVisible: true,
                statusColor: deviceStateColor(device),
                statusHelpText: deviceStateHelp(device)
            });
        }
        return options;
    }

    function pendingOptions() {
        var options = [];
        for (var i = 0; i < pendingRows.length; i++)
            options.push({
                value: pendingRows[i].id,
                label: pendingRows[i].label
            });
        return options;
    }

    function openAdd() {
        addOpen = true;
        acceptOpen = false;
        foldersOpen = false;
        if (syncthing)
            syncthing.refresh();
    }

    function openAccept() {
        if (!selectedPending)
            return;
        acceptOpen = true;
        addOpen = false;
        foldersOpen = false;
    }

    function openFolders() {
        if (!selectedDevice)
            return;
        foldersOpen = true;
        addOpen = false;
        acceptOpen = false;
    }

    function closePopups() {
        deviceSelector.close();
        pendingSelector.close();
        addForm.closePopups();
        foldersForm.closePopups();
    }

    onRemoteRowsChanged: ensureSelections()
    onPendingRowsChanged: ensureSelections()
    Component.onCompleted: ensureSelections()

    Connections {
        target: root.syncthing
        function onFolderMutationNoticeChanged() {
            if (!root.submitting || !root.syncthing.folderMutationNotice)
                return;
            var deviceAdded = root.addOpen || root.acceptOpen;
            root.submitting = false;
            root.addOpen = false;
            root.acceptOpen = false;
            root.foldersOpen = false;
            if (deviceAdded)
                Qt.callLater(function () {
                    root.controller.scrollToTop();
                });
        }
        function onFolderMutationErrorChanged() {
            if (root.syncthing.folderMutationError)
                root.submitting = false;
        }
    }

    width: parent ? parent.width : implicitWidth
    spacing: Style.space(8)

    RowLayout {
        width: parent.width
        spacing: Style.space(6)

        SyncshellDropdown {
            id: deviceSelector
            visible: root.remoteRows.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Style.spacing.controlHeight
            showLabel: false
            rowHeight: Style.spacing.controlHeight
            value: root.selectedDeviceId
            options: root.deviceOptions()
            foreground: root.foreground
            fontFamily: root.fontFamily
            hasCursor: root.keyboardCursor === deviceSelector
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(deviceSelector);
            }
            onChanged: function (value) {
                root.selectedDeviceId = value;
                deviceSelector.value = Qt.binding(function () {
                    return root.selectedDeviceId;
                });
            }
        }

        Text {
            visible: root.remoteRows.length === 0
            Layout.fillWidth: true
            text: "No remote devices configured."
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
        }

        SquareActionButton {
            id: addDeviceButton
            glyph: "\uf067"
            helpText: "Add device"
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: root.syncthing && root.syncthing.online && !root.syncthing.folderMutationBusy
            hasCursor: root.keyboardCursor === addDeviceButton
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(addDeviceButton);
            }
            onClicked: {
                if (root.addOpen)
                    root.addOpen = false;
                else
                    root.openAdd();
            }
        }

        SquareActionButton {
            id: deviceFoldersButton
            visible: root.remoteRows.length > 0
            glyph: "󰉓"
            helpText: "View folder shared\nwith selected device"
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: root.selectedDevice && !root.syncthing.folderMutationBusy
            hasCursor: root.keyboardCursor === deviceFoldersButton
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(deviceFoldersButton);
            }
            onClicked: {
                if (root.foldersOpen)
                    root.foldersOpen = false;
                else
                    root.openFolders();
            }
        }

        SquareActionButton {
            id: removeDeviceButton
            glyph: "\uf00d"
            helpText: "Remove selected device"
            enabled: root.selectedDevice && root.syncthing && root.syncthing.online && !root.syncthing.folderMutationBusy
            foreground: root.urgent
            fontFamily: root.fontFamily
            hasCursor: root.keyboardCursor === removeDeviceButton
            onHovered: function (hovered) {
                if (hovered)
                    root.actionHovered(removeDeviceButton);
            }
            onClicked: root.controller.requestDeviceRemoval(root.selectedDevice)
        }
    }

    DeviceCard {
        id: deviceCard
        visible: !!root.selectedDevice
        width: parent.width
        device: root.selectedDevice || ({})
        controller: root.controller
        online: root.syncthing ? root.syncthing.online : false
        mutationBusy: root.syncthing ? root.syncthing.folderMutationBusy : false
        actionBusy: root.syncthing && root.syncthing.folderMutationBusy && root.syncthing.folderMutationId === root.selectedDeviceId && (root.syncthing.folderMutationAction === "device-pause" || root.syncthing.folderMutationAction === "device-resume")
        stateLabel: root.deviceState(root.selectedDevice)
        stateColor: root.deviceStateColor(root.selectedDevice)
        foreground: root.foreground
        dim: root.dim
        warning: root.warning
        fontFamily: root.fontFamily
        keyboardCursor: root.keyboardCursor
        onActionHovered: function (action) {
            root.actionHovered(action);
        }
        onEditRequested: root.controller.openDeviceInWebUi(root.selectedDeviceId)
        onPauseRequested: function (paused) {
            if (root.syncthing && root.selectedDevice)
                root.syncthing.setDevicePaused(root.selectedDevice.id, paused, root.selectedDevice.name);
        }
    }

    Text {
        visible: root.selectedDevice && root.selectedDevice.folderIds.length === 0 && !root.foldersOpen
        width: parent.width
        text: "No folders are shared. Use the \uf1e0-button to share a folder."
        textFormat: Text.PlainText
        color: root.warning
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
    }

    SideCardMenu {
        panel: root.cardAnchor
        trigger: deviceFoldersButton
        shown: root.foldersOpen && root.selectedDevice && root.visible && root.controller.opened
        onOpened: foldersForm.reset()
        onClosed: {
            root.foldersOpen = false;
            foldersForm.reset();
        }

        contentItem: DeviceFoldersForm {
            id: foldersForm
            controller: root.controller
            syncthing: root.syncthing
            device: root.selectedDevice
            submitting: root.submitting
            foreground: root.foreground
            urgent: root.urgent
            warning: root.warning
            fontFamily: root.fontFamily
            onCanceled: root.foldersOpen = false
            onSubmissionStarted: function (started) {
                root.submitting = started;
            }
        }
    }

    SideCardMenu {
        panel: root.cardAnchor
        trigger: addDeviceButton
        shown: root.addOpen && root.visible && root.controller.opened
        onOpened: addForm.reset()
        onClosed: {
            root.addOpen = false;
            addForm.reset();
        }

        contentItem: AddRemoteDeviceForm {
            id: addForm
            controller: root.controller
            syncthing: root.syncthing
            submitting: root.submitting
            foreground: root.foreground
            dim: root.dim
            urgent: root.urgent
            warning: root.warning
            fontFamily: root.fontFamily
            onCanceled: root.addOpen = false
            onSubmissionStarted: function (started) {
                root.submitting = started;
            }
        }
    }

    Column {
        visible: root.pendingRows.length > 0
        width: parent.width
        spacing: Style.space(6)

        PanelSectionHeader {
            text: "PENDING DEVICE REQUESTS"
            foreground: root.foreground
            fontFamily: root.fontFamily
        }

        RowLayout {
            width: parent.width
            spacing: Style.space(6)

            SyncshellDropdown {
                id: pendingSelector
                Layout.fillWidth: true
                Layout.preferredHeight: Style.spacing.controlHeight
                showLabel: false
                rowHeight: Style.spacing.controlHeight
                value: root.selectedPendingId
                options: root.pendingOptions()
                interactive: options.length > 1
                helpText: root.selectedPending ? "Remote device " + (root.selectedPending.name || root.selectedPending.shortId) + " attempted to connect." : ""
                foreground: root.foreground
                fontFamily: root.fontFamily
                hasCursor: root.keyboardCursor === pendingSelector
                onHovered: function (hovered) {
                    if (hovered)
                        root.actionHovered(pendingSelector);
                }
                onChanged: function (value) {
                    root.selectedPendingId = value;
                    pendingSelector.value = Qt.binding(function () {
                        return root.selectedPendingId;
                    });
                }
            }

            TooltipButton {
                id: acceptDeviceButton
                iconText: "\uf00c"
                Layout.preferredWidth: Style.spacing.controlHeight
                Layout.preferredHeight: Style.spacing.controlHeight
                helpText: "Accept remote device connection"
                bordered: true
                foreground: root.success
                fontFamily: root.fontFamily
                iconSize: Style.font.icon
                enabled: root.selectedPending && !root.syncthing.folderMutationBusy
                hasCursor: root.keyboardCursor === acceptDeviceButton
                onHovered: function (hovered) {
                    if (hovered)
                        root.actionHovered(acceptDeviceButton);
                }
                onClicked: root.openAccept()
            }

            TooltipButton {
                id: dismissDeviceButton
                iconText: "\uf00d"
                Layout.preferredWidth: Style.spacing.controlHeight
                Layout.preferredHeight: Style.spacing.controlHeight
                helpText: "Dismiss incoming device request"
                bordered: true
                foreground: root.urgent
                fontFamily: root.fontFamily
                iconSize: Style.font.icon
                enabled: root.selectedPending && !root.syncthing.folderMutationBusy
                hasCursor: root.keyboardCursor === dismissDeviceButton
                onHovered: function (hovered) {
                    if (hovered)
                        root.actionHovered(dismissDeviceButton);
                }
                onClicked: root.controller.requestPendingDeviceDismiss(root.selectedPending)
            }
        }
    }

    SideCardMenu {
        panel: root.cardAnchor
        trigger: acceptDeviceButton
        shown: root.acceptOpen && root.selectedPending && root.visible && root.controller.opened
        onOpened: acceptForm.reset()
        onClosed: {
            root.acceptOpen = false;
            acceptForm.reset();
        }

        contentItem: AcceptRemoteDeviceForm {
            id: acceptForm
            controller: root.controller
            syncthing: root.syncthing
            device: root.selectedPending
            submitting: root.submitting
            foreground: root.foreground
            dim: root.dim
            urgent: root.urgent
            fontFamily: root.fontFamily
            onCanceled: root.acceptOpen = false
            onSubmissionStarted: function (started) {
                root.submitting = started;
            }
        }
    }
}
