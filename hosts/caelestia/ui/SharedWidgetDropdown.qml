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
    property var filterController: null
    property int totalCount: options.length
    property bool filtersOpen: false
    property string localQuery: ""
    readonly property string query: searchOwner ? searchOwner.view.search : localQuery
    readonly property var filtered: options.filter(o => Model.matchesOption(o, query))
    signal chosen(string value)
    signal toggled(string value)

    SharedWidgetBusyButton {
        id: trigger
        anchors.fill: parent
        caption: root.multiple ? (root.selectedIds.length ? root.selectedIds.length + " selected" : root.placeholder) : (root.options.find(o => o.value === root.value)?.label || root.placeholder)
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
        height: Math.min(root.boundary?.height || 540, 540, contentColumn.implicitHeight + padding * 2)
        padding: root.Tokens.padding.medium
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
            radius: root.Tokens.rounding.medium
        }
        contentItem: ColumnLayout {
            id: contentColumn
            RowLayout {
                Layout.fillWidth: true
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
                SharedWidgetSquareActionButton {
                    visible: !!root.filterController
                    icon: "filter_list"
                    help: "Folder filters and sort order"
                    onClicked: root.filtersOpen = !root.filtersOpen
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: root.filtered.length + " of " + root.totalCount + " results"
                color: Colours.palette.m3onSurfaceVariant
            }
            BodyTabFoldersViewOptions {
                Layout.fillWidth: true
                visible: !!root.filterController && root.filtersOpen
                controller: root.filterController
            }
            StyledListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: Math.min(220, contentHeight)
                clip: true
                model: root.filtered
                spacing: root.Tokens.spacing.extraSmall
                keyNavigationEnabled: true
                QQC.ScrollBar.vertical: StyledScrollBar {
                    flickable: list
                }
                delegate: SharedWidgetBusyButton {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    caption: (root.multiple && root.selectedIds.includes(modelData.value) ? "[x] " : "") + modelData.label + (modelData.status ? " · " + modelData.status : "") + (modelData.detail ? "\n" + modelData.detail : "")
                    help: modelData.help || modelData.detail || ""
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
            SharedWidgetBusyButton {
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
