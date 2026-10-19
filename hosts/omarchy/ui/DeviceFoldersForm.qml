import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
    id: root

    property var controller
    property var syncthing
    property var device
    property bool submitting: false
    property var draftFolderIds: []
    property color foreground: Commons.Color.foreground
    property color urgent: Commons.Color.urgent
    property var originalFolderIds: []
    property string draftDeviceId: ""
    required property color warning
    property string fontFamily: Style.font.family
    readonly property bool popupOpen: folderPicker.popupOpen || unconfirmedPicker.popupOpen
    readonly property var existingOptions: folderOptions(false)
    readonly property var unconfirmedOptions: folderOptions(true)

    signal canceled
    signal submissionStarted(bool started)

    function folderOptions(unconfirmed) {
        var options = [];
        var ids = device ? device.folderIds || [] : [];
        for (let i = 0; i < ids.length; i++) {
            let state = (device.remoteFolderStates || {})[ids[i]] || "unknown";
            let confirmed = state === "valid" || state === "paused";
            if (unconfirmed === confirmed)
                continue;
            let folder = controller.folderById(ids[i]);
            options.push({
                value: ids[i],
                label: String(folder && folder.label || ids[i]),
                description: state === "notSharing" ? "Remote is not sharing back" : !confirmed ? "Remote acceptance unconfirmed" : state === "paused" ? "Remote folder paused" : ""
            });
        }
        return options;
    }

    function reset() {
        draftDeviceId = device ? device.id : "";
        originalFolderIds = device ? (device.folderIds || []).slice() : [];
        draftFolderIds = originalFolderIds.slice();
    }

    function reconcileDevice() {
        if (!device || device.id !== draftDeviceId) {
            reset();
            return;
        }
        var current = device.folderIds || [];
        draftFolderIds = current.filter(function (id) {
            return originalFolderIds.indexOf(id) < 0 || draftFolderIds.indexOf(id) >= 0;
        });
        originalFolderIds = current.slice();
    }

    function selectedValues(options) {
        return options.map(function (option) {
            return option.value;
        }).filter(function (id) {
            return draftFolderIds.indexOf(id) >= 0;
        });
    }

    function setGroupValues(options, values) {
        var ids = options.map(function (option) {
            return option.value;
        });
        draftFolderIds = originalFolderIds.filter(function (id) {
            return ids.indexOf(id) >= 0 ? values.indexOf(id) >= 0 : draftFolderIds.indexOf(id) >= 0;
        });
    }

    function removedFolderIds() {
        var removed = [];
        var original = originalFolderIds;
        for (let i = 0; i < original.length; i++) {
            if (draftFolderIds.indexOf(original[i]) < 0)
                removed.push(original[i]);
        }
        return removed;
    }

    function closePopups() {
        folderPicker.close();
        unconfirmedPicker.close();
    }

    onDeviceChanged: reconcileDevice()
    onVisibleChanged: if (visible)
        reset()

    width: parent ? parent.width : implicitWidth
    implicitHeight: content.implicitHeight + Style.space(8)

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: Style.space(8)
        anchors.topMargin: 0
        spacing: Style.space(6)

        InlineFormHeader {
            title: "SHARED WITH " + String(root.device && root.device.name || "DEVICE")
            foreground: root.foreground
            cancelColor: root.urgent
            fontFamily: root.fontFamily
            cancelEnabled: !root.submitting
            onCanceled: root.canceled()
        }

        Text {
            visible: root.originalFolderIds.length === 0
            width: parent.width
            text: "No folders are currently shared with this device."
            textFormat: Text.PlainText
            color: root.warning
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
        }

        SyncshellMultiSelect {
            id: folderPicker
            visible: root.originalFolderIds.length > 0
            enabled: options.length > 0 && !root.submitting
            width: parent.width
            label: "Existing shares"
            values: root.selectedValues(options)
            options: root.existingOptions
            noSelectionText: options.length ? "No folders selected" : "No confirmed shares"
            placeholderText: "Find a folder..."
            foreground: root.foreground
            fontFamily: root.fontFamily
            onChanged: function (values) {
                root.setGroupValues(options, values);
            }
            onPopupOpenChanged: if (popupOpen)
                unconfirmedPicker.close()
        }

        Row {
            visible: root.originalFolderIds.length > 0
            width: parent.width
            spacing: Style.spacing.labelGap

            Text {
                id: unconfirmedLabel
                text: "Unconfirmed shares"
                textFormat: Text.PlainText
                color: Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
            }

            Text {
                id: unconfirmedHint
                visible: root.unconfirmedOptions.length > 0
                width: parent.width - unconfirmedLabel.implicitWidth - parent.spacing
                text: fullHint.width <= width ? fullHint.text : "(acceptance pending/device offline)"
                textFormat: Text.PlainText
                color: root.warning
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.NoWrap
                elide: Text.ElideRight

                TextMetrics {
                    id: fullHint
                    font: unconfirmedHint.font
                    text: "(acceptance pending/device offline)"
                }
            }
        }

        SyncshellMultiSelect {
            id: unconfirmedPicker
            visible: root.originalFolderIds.length > 0
            enabled: options.length > 0 && !root.submitting
            width: parent.width
            label: "Unconfirmed shares"
            showLabel: false
            values: root.selectedValues(options)
            options: root.unconfirmedOptions
            noSelectionText: options.length ? "No folders selected" : "No unconfirmed shares"
            placeholderText: "Find a folder..."
            foreground: root.foreground
            fontFamily: root.fontFamily
            onChanged: function (values) {
                root.setGroupValues(options, values);
            }
            onPopupOpenChanged: if (popupOpen)
                folderPicker.close()
        }

        Text {
            visible: root.originalFolderIds.length > 0
            width: parent.width
            text: "  Use -button (share folder) to restore a folder."
            textFormat: Text.PlainText
            color: root.warning
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }

        Button {
            visible: root.originalFolderIds.length > 0
            width: parent.width
            text: root.submitting ? "SAVING..." : "SAVE SHARING"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: root.device && root.syncthing && !root.submitting && !root.syncthing.folderMutationBusy && root.removedFolderIds().length > 0
            onClicked: root.submissionStarted(root.syncthing.removeDeviceFolderShares(root.device.id, root.removedFolderIds(), root.device.name))
        }
    }
}
