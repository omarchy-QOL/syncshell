pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import "."
import "../models/PanelModel.js" as Model

FocusScope {
    id: root
    objectName: "syncshellPanel"
    required property var controller
    required property var owner
    required property real availableWidth
    required property real availableHeight
    required property real anchorCenter
    property var formTrigger: null
    property real mainWidth: Math.min(availableWidth - 32, Tokens.font.body.small.pointSize * 40)
    property real formWidth: Tokens.font.body.small.pointSize * 36
    readonly property real gap: Tokens.spacing.large
    readonly property bool hasForm: !!controller.view.form
    readonly property real mainNaturalHeight: header.implicitHeight + bodyContent.implicitHeight + footer.implicitHeight + gap * 2
    readonly property var geometry: Model.geometry(mainWidth, mainNaturalHeight, hasForm ? formWidth : 0, sideContent.implicitHeight + gap * 2, controller.view.formAnchor, availableWidth, availableHeight, anchorCenter, gap)
    signal dismissed
    implicitWidth: Math.max(1, geometry.width)
    implicitHeight: Math.max(1, geometry.height)

    function form(kind, target, trigger) {
        formTrigger = trigger;
        controller.openForm(kind, target, trigger.mapToItem(mainPane, 0, 0).y);
    }
    function focusFirst(item) {
        if (!item || !item.visible || !item.enabled)
            return false;
        if (item.activeFocusOnTab) {
            item.forceActiveFocus();
            return true;
        }
        for (let child of item.children || [])
            if (focusFirst(child))
                return true;
        return false;
    }
    function focusEditor(item) {
        if (!item || !item.visible || !item.enabled)
            return false;
        if (item.objectName === "syncshellInitialFocus") {
            item.forceActiveFocus();
            return true;
        }
        for (let child of item.children || [])
            if (focusEditor(child))
                return true;
        return false;
    }
    function restore(name) {
        if (controller.view.confirmation)
            return;
        Qt.callLater(() => {
            if (!root.visible)
                return;
            if (name === "form" && root.hasForm) {
                if (!focusEditor(sideContent))
                    focusFirst(sideContent);
            } else if (name === "formTrigger" && root.formTrigger?.enabled)
                root.formTrigger.forceActiveFocus();
            else
                folderTab.forceActiveFocus();
        });
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            event.accepted = true;
            if (controller.view.confirmation)
                controller.cancelConfirmation();
            else if (controller.view.picking)
                controller.update({
                    picking: false
                });
            else if (hasForm)
                controller.cancelForm();
            else
                dismissed();
            return;
        }
        var editor = root.Window.window?.activeFocusItem;
        if (editor && (editor.cursorPosition !== undefined || editor.inputMethodComposing !== undefined))
            return;
        if ([Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right].includes(event.key)) {
            let candidate = editor;
            let forward = event.key === Qt.Key_Down || event.key === Qt.Key_Right;
            for (let i = 0; candidate && i < 150; i++) {
                candidate = candidate.nextItemInFocusChain(forward);
                let ancestor = candidate;
                while (ancestor && ancestor !== root)
                    ancestor = ancestor.parent;
                if (ancestor === root && candidate.activeFocusOnTab && candidate.enabled && candidate.visible) {
                    candidate.forceActiveFocus();
                    event.accepted = true;
                    return;
                }
            }
        }
        if (event.isAutoRepeat || controller.busy || controller.view.confirmation || hasForm)
            return;
        if (event.key === Qt.Key_R)
            controller.service.rescanAllFolders();
        else if (event.key === Qt.Key_W)
            controller.service.openWebUi();
        else if (event.key === Qt.Key_P)
            controller.requestServiceToggle();
        else if (event.key === Qt.Key_S)
            form("settings", null, footerActions.settingsTrigger);
        else if (event.key === Qt.Key_Q)
            dismissed();
        else
            return;
        event.accepted = true;
    }
    StyledFlickable {
        id: outerScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: root.geometry.stacked ? root.geometry.formY + root.geometry.formHeight : height
        interactive: root.geometry.stacked && contentHeight > height
        clip: true
        QQC.ScrollBar.vertical: StyledScrollBar {
            flickable: outerScroll
        }
        ColumnLayout {
            id: mainPane
            x: 0
            y: root.geometry.mainY
            width: Math.min(root.mainWidth, root.width)
            height: root.geometry.mainHeight
            spacing: root.gap
            Header {
                id: header
                Layout.fillWidth: true
                controller: root.controller
                brandedIcon: root.owner.settings?.icon === "branded"
            }
            StyledFlickable {
                id: bodyScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: bodyContent.implicitHeight
                contentWidth: width
                contentHeight: bodyContent.implicitHeight
                clip: true
                interactive: contentHeight > height
                QQC.ScrollBar.vertical: StyledScrollBar {
                    flickable: bodyScroll
                }
                ColumnLayout {
                    id: bodyContent
                    width: parent.width
                    spacing: root.gap
                    RowLayout {
                        SharedWidgetBusyButton {
                            id: folderTab
                            caption: "Folders (" + root.controller.service.folderCount + ")"
                            isToggle: true
                            type: TextButton.Tonal
                            checked: root.controller.view.tab === "folders"
                            onClicked: root.controller.update({
                                tab: "folders"
                            })
                        }
                        SharedWidgetBusyButton {
                            caption: "Devices (" + root.controller.service.remoteDevices().length + ")"
                            isToggle: true
                            type: TextButton.Tonal
                            checked: root.controller.view.tab === "devices"
                            onClicked: root.controller.update({
                                tab: "devices"
                            })
                        }
                    }
                    RowLayout {
                        SharedWidgetDropdown {
                            id: mainSelector
                            Layout.fillWidth: true
                            searchOwner: root.controller
                            filterController: root.controller.view.tab === "folders" ? root.controller : null
                            totalCount: root.controller.view.tab === "folders" ? root.controller.service.folders.length : root.controller.service.remoteDevices().length
                            options: root.controller.view.tab === "folders" ? root.controller.folderOptions : root.controller.deviceOptions
                            value: root.controller.view.tab === "folders" ? root.controller.view.folderId : root.controller.view.deviceId
                            placeholder: "No matching items"
                            onChosen: value => root.controller.update(root.controller.view.tab === "folders" ? {
                                    folderId: value
                                } : {
                                    deviceId: value
                                })
                        }
                        SharedWidgetSquareActionButton {
                            id: add
                            icon: "add"
                            help: root.controller.view.tab === "folders" ? "Add folder (locally)" : "Add device"
                            disabled: !root.controller.fresh || root.controller.busy
                            onClicked: root.form(root.controller.view.tab === "folders" ? "add-folder" : "add-device", null, add)
                        }
                        SharedWidgetSquareActionButton {
                            id: share
                            icon: root.controller.view.tab === "folders" ? "share" : "folder_shared"
                            help: root.controller.view.tab === "folders" ? "Share folder\n(other device)" : "View folder shared\nwith selected device"
                            disabled: !root.controller.fresh || root.controller.busy || !(root.controller.view.tab === "folders" ? root.controller.folder : root.controller.device)
                            onClicked: root.form(root.controller.view.tab === "folders" ? "share-folder" : "device-folders", root.controller.view.tab === "folders" ? root.controller.folder : root.controller.device, share)
                        }
                        SharedWidgetSquareActionButton {
                            readonly property bool folders: root.controller.view.tab === "folders"
                            readonly property bool paused: folders && !!root.controller.folder?.paused
                            icon: paused ? "link" : "close"
                            success: paused
                            danger: !paused
                            help: folders ? (!root.controller.folder ? "Select a folder" : paused ? "Link folder" : "Unlink folder (locally)") : "Remove selected device"
                            disabled: !(folders ? root.controller.folder : root.controller.device) || !root.controller.fresh || root.controller.busy
                            onClicked: {
                                if (folders)
                                    root.controller.requestFolderLinkChange();
                                else
                                    root.controller.confirm("device.remove", {
                                        deviceId: root.controller.device.id,
                                        deviceName: root.controller.device.name || ""
                                    }, "Remove " + Model.label(root.controller.device) + " from this device?", "Folder sharing with it will be removed locally. Local folders and files remain. The other device is unchanged.");
                            }
                        }
                    }
                    // One height for both tabs, as in Omarchy: the stack takes
                    // the taller page and the cards absorb the difference.
                    StackLayout {
                        Layout.fillWidth: true
                        currentIndex: root.controller.view.tab === "folders" ? 0 : 1
                        ColumnLayout {
                            spacing: root.gap
                            StyledText {
                                Layout.fillWidth: true
                                visible: !!root.controller.folder && !mainSelector.filtered.some(o => o.value === root.controller.view.folderId)
                                text: "Selected folder is hidden by the filter"
                                wrapMode: Text.Wrap
                            }
                            BodyTabFoldersCard {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                controller: root.controller
                            }
                            BodyInvitations {
                                Layout.fillWidth: true
                                controller: root.controller
                                folders: true
                                onFormRequested: (kind, target, trigger) => root.form(kind, target, trigger)
                            }
                        }
                        ColumnLayout {
                            spacing: root.gap
                            BodyTabDevicesCard {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                controller: root.controller
                            }
                            BodyInvitations {
                                Layout.fillWidth: true
                                controller: root.controller
                                folders: false
                                onFormRequested: (kind, target, trigger) => root.form(kind, target, trigger)
                            }
                        }
                    }
                    // A disclosure, as in Omarchy: chevron plus More/Less.
                    IconTextButton {
                        id: moreToggle
                        type: TextButton.Text
                        icon: root.controller.view.more ? "expand_less" : "expand_more"
                        text: root.controller.view.more ? "Less" : "More"
                        activeFocusOnTab: true
                        border.width: activeFocus ? 2 : 0
                        border.color: Colours.palette.m3primary
                        Accessible.role: Accessible.Button
                        Accessible.name: root.controller.view.more ? "Hide details" : "Show details"
                        onClicked: root.controller.update({
                            more: !root.controller.view.more
                        })
                        Keys.onPressed: event => {
                            if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)) {
                                event.accepted = true;
                                if (!event.isAutoRepeat)
                                    clicked();
                            }
                        }
                    }
                    BodyMore {
                        Layout.fillWidth: true
                        controller: root.controller
                        visible: root.controller.view.more
                    }
                }
            }
            ColumnLayout {
                id: footer
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: root.controller.error || root.owner.preferences.error || root.controller.service.lastError || root.controller.service.actionNotice
                    textFormat: Text.PlainText
                    visible: !!text
                    wrapMode: Text.Wrap
                }
                FooterActions {
                    id: footerActions
                    Layout.fillWidth: true
                    controller: root.controller
                    onSettingsRequested: trigger => root.form("settings", null, trigger)
                }
                FooterShortcutHint {}
            }
        }
        StyledRect {
            id: sideSurface
            visible: root.hasForm
            x: root.geometry.stacked ? 0 : root.mainWidth + root.gap
            y: root.geometry.formY
            width: root.geometry.stacked ? root.width : root.formWidth
            height: root.geometry.formHeight
            radius: Tokens.rounding.medium
            color: Colours.palette.m3surfaceContainer
            StyledFlickable {
                id: sideScroll
                anchors.fill: parent
                anchors.margins: root.gap
                contentWidth: width
                contentHeight: sideContent.implicitHeight
                clip: true
                interactive: contentHeight > height
                QQC.ScrollBar.vertical: StyledScrollBar {
                    flickable: sideScroll
                }
                BodyFormSideCard {
                    id: sideContent
                    width: parent.width
                    controller: root.controller
                    owner: root.owner
                    visible: root.hasForm
                }
            }
        }
    }
    SharedDialogConfirm {
        parent: root
        controller: root.controller
    }
    Connections {
        target: root.controller
        function onRestoreFocus(name) {
            root.restore(name);
        }
    }
    Component.onCompleted: restore(controller.view.form ? "form" : "main")
}
