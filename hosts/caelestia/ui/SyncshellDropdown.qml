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

Item {
    id: root
    implicitWidth: trigger.implicitWidth
    implicitHeight: trigger.implicitHeight
    readonly property Item boundary: {
        var item = parent;
        while (item && item.objectName !== "syncshellPanel")
            item = item.parent;
        return item;
    }
    property bool alive: true
    Component.onDestruction: alive = false
    property var options: []
    property string value: ""
    property string placeholder: "Select"
    property bool disabled: false
    property bool multiple: false
    property var selectedIds: []
    property var searchOwner: null
    property string localQuery: ""
    readonly property string query: searchOwner ? searchOwner.view.search : localQuery
    readonly property var filtered: options.filter(o => Model.matchesSearch(o.label + " " + (o.detail || ""), query))
    signal chosen(string value)
    signal toggled(string value)

    BusyButton {
        id: trigger
        anchors.fill: parent
        caption: root.multiple ? root.selectedIds.length + " selected" : (root.options.find(o => o.value === root.value)?.label || root.placeholder)
        disabled: root.disabled
        label.elide: Text.ElideRight
        label.width: width - horizontalPadding * 2
        onClicked: menu.open()
    }
    QQC.Popup {
        id: menu
        parent: trigger
        y: root.boundary ? Math.max(-trigger.mapToItem(root.boundary, 0, 0).y, Math.min(trigger.height, root.boundary.height - trigger.mapToItem(root.boundary, 0, 0).y - height)) : trigger.height
        width: trigger.width
        height: Math.min(root.boundary?.height || 320, 320, contentColumn.implicitHeight + padding * 2)
        padding: Tokens.padding.medium
        modal: true
        focus: true
        closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside
        onOpened: {
            search.forceActiveFocus();
            list.currentIndex = 0;
        }
        onClosed: if (root.alive && root.visible)
            trigger.forceActiveFocus()
        background: StyledRect {
            color: Colours.palette.m3surfaceContainerHigh
            radius: Tokens.rounding.medium
        }
        contentItem: ColumnLayout {
            id: contentColumn
            StyledTextField {
                id: search
                Layout.fillWidth: true
                placeholderText: "Search"
                text: root.query
                onTextEdited: {
                    if (root.searchOwner)
                        root.searchOwner.update({
                            search: text
                        });
                    else
                        root.localQuery = text;
                }
                Keys.onDownPressed: {
                    list.forceActiveFocus();
                    list.currentIndex = 0;
                }
            }
            StyledListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: Math.min(220, contentHeight)
                clip: true
                model: root.filtered
                spacing: Tokens.spacing.extraSmall
                keyNavigationEnabled: true
                QQC.ScrollBar.vertical: StyledScrollBar {
                    flickable: list
                }
                delegate: BusyButton {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    caption: (root.multiple && root.selectedIds.includes(modelData.value) ? "[x] " : "") + modelData.label + (modelData.detail ? "\n" + modelData.detail : "")
                    label.wrapMode: Text.Wrap
                    label.width: width - horizontalPadding * 2
                    isToggle: true
                    type: TextButton.Tonal
                    checked: ListView.isCurrentItem
                    onClicked: {
                        list.currentIndex = index;
                        root.select(modelData.value);
                    }
                }
                Keys.onPressed: event => {
                    if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)) {
                        event.accepted = true;
                        if (!event.isAutoRepeat && root.filtered[currentIndex])
                            root.select(root.filtered[currentIndex].value);
                    }
                }
            }
            StyledText {
                visible: !root.filtered.length
                text: "No matches"
            }
            BusyButton {
                visible: root.multiple
                caption: "Done"
                onClicked: menu.close()
            }
        }
    }
    function select(id) {
        if (multiple)
            toggled(id);
        else {
            chosen(id);
            menu.close();
        }
    }
}
