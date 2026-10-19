import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import "../models/PanelModel.js" as Model
import "../models/PanelNavigation.js" as Navigation

Item {
    id: root
    required property var style
    required property var controller
    property string selectorKey: "folder"
    property string label: "Choose"
    property string help: ""
    property var options: []
    property string selectedId: ""
    property bool multiple: false
    property var selectedIds: []
    property Component headerAccessory: null
    property Component optionsContent: null
    property bool showSummary: true
    signal chosen(string id)
    signal changed(var ids)
    readonly property bool expanded: controller.selector === selectorKey
        || controller.selectorStack.indexOf(selectorKey) >= 0
    readonly property var filtered: options.filter(row => Model.matches(row, controller.queries[selectorKey] || ""))
    readonly property alias triggerItem: trigger
    readonly property alias popupItem: popup
    readonly property bool navigationControl: true
    implicitWidth: trigger.implicitWidth
    implicitHeight: trigger.implicitHeight
    objectName: selectorKey

    function focusControl() { trigger.focusControl(); }
    function select(id) {
        var option = Model.byId(options, id);
        if (!option || option.enabled === false) return;
        if (multiple) changed(Model.toggle(selectedIds, id));
        else { chosen(id); controller.closeSelector(); }
    }
    function enabledIndex(start, direction) {
        for (var index = start; index >= 0 && index < filtered.length; index += direction)
            if (filtered[index].enabled !== false) return index;
        return -1;
    }
    function initialIndex() {
        var selected = multiple ? selectedIds[0] : selectedId;
        var index = filtered.findIndex(row => row.id === selected && row.enabled !== false);
        return index >= 0 ? index : enabledIndex(0, 1);
    }
    function focusList() {
        if (!list.item || !filtered.length) return;
        if (list.item.currentIndex < 0) list.item.currentIndex = enabledIndex(0, 1);
        list.item.forceActiveFocus();
    }
    function handleKey(event) {
        if (controller.selector !== selectorKey) return;
        if (controller.viewOptionsOpen) {
            if (event.key === Qt.Key_Escape) { controller.viewOptionsOpen = false; event.accepted = true; }
            else {
                var focused = root.Window.window ? root.Window.window.activeFocusItem : null;
                if (focused && typeof focused.cursorPosition !== "undefined") return;
                var dx = event.key === Qt.Key_Left || event.key === Qt.Key_H ? -1
                    : event.key === Qt.Key_Right || event.key === Qt.Key_L ? 1 : 0;
                var dy = event.key === Qt.Key_Up || event.key === Qt.Key_K ? -1
                    : event.key === Qt.Key_Down || event.key === Qt.Key_J ? 1 : 0;
                if ((dx || dy) && viewOptions.item) {
                    var next = Navigation.move(viewOptions.item, focused, dx, dy);
                    if (next) { next.focusControl(); root.revealOption(next); }
                    event.accepted = true;
                }
            }
            return;
        }
        var editing = search.item && search.item.activeFocus;
        if (!editing && event.key === Qt.Key_Slash) search.focusControl();
        else if (!editing && optionsContent && (event.key === Qt.Key_Right || event.key === Qt.Key_L)) controller.viewOptionsOpen = true;
        else if (event.key === Qt.Key_Escape || !editing && event.key === Qt.Key_Q) controller.closeSelector();
        else if (event.key === Qt.Key_Down || !editing && event.key === Qt.Key_J) {
            if (list.item) {
                if (!editing) {
                    var next = enabledIndex(list.item.currentIndex + 1, 1);
                    if (next >= 0) list.item.currentIndex = next;
                }
                focusList();
            }
        } else if (event.key === Qt.Key_Up || !editing && event.key === Qt.Key_K) {
            var previous = list.item ? enabledIndex(list.item.currentIndex - 1, -1) : -1;
            if (previous >= 0) list.item.currentIndex = previous;
            else search.focusControl();
        } else if (!editing && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
            if (!event.isAutoRepeat && list.item && filtered[list.item.currentIndex]) select(filtered[list.item.currentIndex].id);
        } else return;
        event.accepted = true;
    }
    function revealOption(item) {
        if (!item || optionScroll.height <= 0 || !viewOptions.item || !Navigation.contains(viewOptions.item, item)) return;
        var point = item.mapToItem(optionScroll.contentItem, 0, 0);
        if (point.y < optionScroll.contentY) optionScroll.contentY = point.y;
        else if (point.y + item.height > optionScroll.contentY + optionScroll.height)
            optionScroll.contentY = point.y + item.height - optionScroll.height;
        optionScroll.contentY = Math.max(0, Math.min(optionScroll.contentY, Math.max(0, optionScroll.contentHeight - optionScroll.height)));
    }
    function placePopup() {
        if (!popup.parent) return;
        var point = trigger.mapToItem(popup.parent, 0, 0);
        popup.width = Math.max(1, Math.min(style.menuWidth, popup.parent.width - 16));
        popup.x = Math.max(8, Math.min(point.x, popup.parent.width - popup.width - 8));
        popup.height = Math.min(popup.implicitHeight, Math.max(1, popup.parent.height - 16));
        popup.y = Math.max(8, Math.min(point.y + trigger.height + 4,
            popup.parent.height - popup.height - 8));
        if (point.y + trigger.height + popup.height > popup.parent.height - 8
                && point.y - popup.height - 4 >= 8) popup.y = point.y - popup.height - 4;
    }
    onFilteredChanged: if (list.item) {
        list.item.currentIndex = initialIndex();
        selectionPosition.restart();
    }
    onExpandedChanged: {
        if (expanded) popup.open();
        else popup.close();
    }
    Component.onCompleted: if (expanded) popup.open()
    BusyButton {
        id: trigger
        objectName: root.selectorKey + "-trigger"
        anchors.fill: parent
        style: root.style
        help: root.help
        selected: root.expanded
        text: root.multiple && root.showSummary ? root.label + " · " + root.selectedIds.filter(id => root.options.some(row => row.id === id)).length + " selected" : root.label
        onClicked: root.controller.openSelector(root.selectorKey)
    }
    Popup {
        id: popup
        objectName: root.selectorKey + "-popup"
        parent: Overlay.overlay
        popupType: Popup.Item
        modal: false
        dim: false
        focus: true
        padding: root.style.spacing
        closePolicy: Popup.CloseOnPressOutside
        background: Loader { sourceComponent: root.style.surfaceComponent }
        onOpened: {
            root.placePopup();
            if (list.item) {
                list.item.currentIndex = root.initialIndex();
                list.item.positionViewAtIndex(list.item.currentIndex, ListView.Contain);
            }
            root.focusList();
            selectionPosition.restart();
        }
        onClosed: {
            if (root.controller.presentationActive && root.controller.selector === root.selectorKey) root.controller.closeSelector();
        }
        contentItem: ColumnLayout {
            spacing: root.style.spacing
            Keys.priority: Keys.AfterItem
            Keys.onPressed: event => root.handleKey(event)
            RowLayout {
                Layout.fillWidth: true
                NativeField {
                    id: search
                    objectName: root.selectorKey + "-search"
                    style: root.style
                    Layout.fillWidth: true
                    placeholder: "Search names, IDs and paths"
                    text: root.controller.queries[root.selectorKey] || ""
                    onEdited: value => {
                        root.controller.queries = Object.assign({}, root.controller.queries, {[root.selectorKey]: value});
                        root.controller.query = value;
                    }
                    Keys.onDownPressed: root.focusList()
                    onAccepted: {
                        if (root.filtered.length === 1) root.select(root.filtered[0].id);
                        else root.focusList();
                    }
                }
                Loader { sourceComponent: root.headerAccessory }
            }
            Flickable {
                id: optionScroll
                objectName: root.selectorKey + "-view-scroll"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: Math.min(root.style.controlHeight * 7, contentHeight)
                visible: root.optionsContent !== null && root.controller.viewOptionsOpen
                clip: true
                contentWidth: width
                contentHeight: viewOptions.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: optionBar.item as ScrollBar
                Loader { id: optionBar; sourceComponent: root.style.scrollBar }
                Loader {
                    id: viewOptions
                    width: optionScroll.width
                    active: optionScroll.visible
                    sourceComponent: root.optionsContent
                }
            }
            NativeText {
                style: root.style
                visible: !root.controller.viewOptionsOpen
                Layout.fillWidth: true
                muted: true
                text: root.filtered.length + " of " + root.options.length + " results"
            }
            BusyButton {
                objectName: root.selectorKey + "-all"
                style: root.style
                visible: root.multiple && !root.controller.viewOptionsOpen
                enabled: root.filtered.length > 0
                selected: Model.allState(root.selectedIds, root.filtered.map(row => row.id)) !== "none"
                selectionState: Model.allState(root.selectedIds, root.filtered.map(row => row.id)) === "mixed" ? "mixed"
                    : Model.allState(root.selectedIds, root.filtered.map(row => row.id)) === "all" ? "checked" : "empty"
                text: "All visible"
                onClicked: root.changed(Model.toggleAll(root.selectedIds, root.filtered.map(row => row.id)))
            }
            Loader {
                id: list
                visible: !root.controller.viewOptionsOpen
                objectName: root.selectorKey + "-list"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Math.min(root.style.controlHeight, Layout.preferredHeight)
                Layout.preferredHeight: item ? Math.min(root.style.controlHeight * 6, item.contentHeight) : 0
                sourceComponent: root.style.list
                Binding { target: list.item; property: "model"; value: root.filtered }
                Binding { target: list.item; property: "delegate"; value: rowDelegate }
                Binding { target: list.item; property: "keyNavigationEnabled"; value: false }
                Binding { target: list.item; property: "activeFocusOnTab"; value: true }
                Keys.onPressed: event => root.handleKey(event)
            }
            NativeText {
                objectName: root.selectorKey + "-empty"
                style: root.style
                visible: root.filtered.length === 0
                text: root.options.length ? "No matches. Change the search or filters." : "No choices available"
                Layout.fillWidth: true
            }
        }
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() {
            if (root.controller.viewOptionsOpen && root.Window.window)
                root.revealOption(root.Window.window.activeFocusItem);
        }
    }
    Timer {
        id: optionFocus
        interval: 32
        onTriggered: if (root.expanded && root.controller.viewOptionsOpen && viewOptions.item) {
            var controls = Navigation.controls(viewOptions.item);
            if (controls.length) controls[0].focusControl();
        }
    }
    Timer {
        id: selectionPosition
        interval: 32
        onTriggered: if (root.expanded && list.item && list.item.currentIndex >= 0)
            list.item.positionViewAtIndex(list.item.currentIndex, ListView.Contain)
    }
    Timer { interval: 16; running: popup.visible; repeat: true; onTriggered: root.placePopup() }
    Component {
        id: rowDelegate
        Loader {
            id: row
            required property var modelData
            required property int index
            width: list.width
            height: item ? item.implicitHeight : root.style.controlHeight
            sourceComponent: root.style.choice
            Binding { target: row.item; property: "enabled"; value: row.modelData.enabled !== false }
            Binding { target: row.item; property: "label"; value: row.modelData.label }
            Binding { target: row.item; property: "detail"; value: row.modelData.description || "" }
            Binding { target: row.item; property: "statusText"; value: row.modelData.status || row.modelData.trailing || "" }
            Binding { target: row.item; property: "statusColor"; value: root.style.colorFor(row.modelData.role || "foreground") }
            Binding { target: row.item; property: "help"; value: row.modelData.help || row.modelData.description || "" }
            Binding { target: row.item; property: "current"; value: list.item && list.item.currentIndex === row.index && list.item.activeFocus }
            Binding { target: row.item; property: "selected"; value: root.multiple ? root.selectedIds.indexOf(row.modelData.id) >= 0 : root.selectedId === row.modelData.id }
            Connections { target: row.item; function onActivated() { root.select(row.modelData.id); } }
        }
    }
    Connections {
        target: root.controller
        function onViewOptionsOpenChanged() {
            if (!root.optionsContent || !root.expanded) return;
            Qt.callLater(() => {
                if (!root.expanded || !popup.visible) return;
                if (root.controller.viewOptionsOpen && viewOptions.item) {
                    optionScroll.contentY = 0;
                    optionFocus.restart();
                } else {
                    var accessory = Navigation.find(popup.contentItem, "folder-view-options");
                    if (accessory) accessory.focusControl();
                }
            });
        }
        function onFocusRequested(key) {
            if (key === root.selectorKey + "-trigger") trigger.focusControl();
            else if (key === "selector-search" && root.controller.selector === root.selectorKey) search.focusControl();
        }
    }
}
