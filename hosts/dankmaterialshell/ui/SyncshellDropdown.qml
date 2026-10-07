import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets
import "../models/PanelModel.js" as Model

Item {
    id: root
    property var options: []
    property string value: ""
    property string placeholder: "Choose"
    property string localSearchText: ""
    property var searchOwner: null
    property string searchKey: ""
    readonly property string searchText: searchOwner ? searchOwner[searchKey] : localSearchText
    property int totalCount: options.length
    property bool multiple: false
    property var selectedValues: []
    property var parentPopout: null
    property Component accessory: null
    property bool opened: false
    readonly property var tracker: parentPopout ? parentPopout.transientSurfaceTracker : null
    readonly property var filteredOptions: options.filter(function (option) {
        return Model.matchesOption(option, root.searchText);
    })
    readonly property string displayText: {
        if (multiple)
            return selectedValues.length ? selectedValues.length + " selected" : placeholder;
        for (var index = 0; index < options.length; index++) {
            if (options[index].value === value)
                return options[index].label;
        }
        return placeholder;
    }
    implicitHeight: 40
    implicitWidth: 220
    signal selected(string value)
    signal toggled(string value)

    function close() {
        if (!opened)
            return;
        opened = false;
        trigger.forceActiveFocus();
    }

    function choose(index) {
        var row = filteredOptions[index];
        if (!row)
            return;
        if (multiple)
            toggled(row.value);
        else {
            selected(row.value);
            close();
        }
    }

    function open() {
        if (opened) {
            close();
            return;
        }
        var host = root.QsWindow.window;
        if (!host)
            return;
        menu.anchor.window = host;
        menu.anchor.rect.x = 0;
        menu.anchor.rect.y = 0;
        menu.anchor.edges = Edges.Top | Edges.Left;
        menu.anchor.gravity = Edges.Bottom | Edges.Right;
        menu.anchor.adjustment = PopupAdjustment.None;
        menu.width = host.width;
        menu.height = host.height;
        var point = root.QsWindow.itemPosition(trigger);
        menu.originX = point.x;
        menu.originY = point.y;
        menu.anchor.updateAnchor();
        opened = true;
        Qt.callLater(function () {
            search.forceActiveFocus();
        });
    }

    onOpenedChanged: if (tracker)
        tracker.setActive(root, opened, opened ? menu : null)
    Component.onDestruction: if (tracker)
        tracker.unregister(root)
    Connections {
        target: root.tracker
        function onCloseRequested() {
            root.close();
        }
    }

    DankButton {
        id: trigger
        width: parent.width
        text: ""
        onClicked: root.open()
        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            StyledText {
                text: root.displayText
                textFormat: Text.PlainText
                maximumLineCount: 1
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            DankIcon {
                name: root.opened ? "expand_less" : "expand_more"
                size: 18
            }
        }
    }

    PopupWindow {
        id: menu
        property real originX: 0
        property real originY: 0
        visible: root.opened
        color: "transparent"
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
        StyledRect {
            width: Math.min(menu.width, Math.max(root.width, 310))
            height: Math.min(menu.height, content.implicitHeight + Theme.spacingM * 2)
            x: Math.max(0, Math.min(menu.width - width, menu.originX))
            y: Math.max(0, Math.min(menu.height - height, menu.originY + root.height + height <= menu.height ? menu.originY + root.height : menu.originY - height))
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            MouseArea {
                anchors.fill: parent
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                }
            }
            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS
                DankTextField {
                    id: search
                    Layout.fillWidth: true
                    placeholderText: "Search"
                    text: root.searchText
                    onTextEdited: {
                        if (root.searchOwner)
                            root.searchOwner[root.searchKey] = text;
                        else
                            root.localSearchText = text;
                    }
                    Keys.onDownPressed: {
                        list.currentIndex = 0;
                        list.forceActiveFocus();
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.filteredOptions.length + " of " + root.totalCount + " results"
                    color: Theme.surfaceVariantText
                }
                Loader {
                    Layout.fillWidth: true
                    sourceComponent: root.accessory
                    visible: sourceComponent !== null
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: root.filteredOptions.length === 0
                    text: "No matching entries"
                    color: Theme.surfaceVariantText
                }
                DankListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: Math.min(300, contentHeight)
                    clip: true
                    model: root.filteredOptions
                    currentIndex: -1
                    keyNavigationEnabled: true
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            if (!event.isAutoRepeat)
                                root.choose(currentIndex);
                            event.accepted = true;
                        }
                    }
                    delegate: StyledRect {
                        required property var modelData
                        required property int index
                        width: list.width
                        height: row.implicitHeight + Theme.spacingS * 2
                        color: ListView.isCurrentItem ? Theme.surfaceVariant : "transparent"
                        radius: Theme.cornerRadius
                        RowLayout {
                            id: row
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            DankIcon {
                                visible: root.multiple
                                name: root.selectedValues.indexOf(modelData.value) >= 0 ? "check_box" : "check_box_outline_blank"
                                size: 20
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                StyledText {
                                    text: modelData.label
                                    textFormat: Text.PlainText
                                    Layout.fillWidth: true
                                    maximumLineCount: 1
                                }
                                StyledText {
                                    text: modelData.description || modelData.value
                                    textFormat: Text.PlainText
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                    Layout.fillWidth: true
                                    maximumLineCount: 1
                                    elide: Text.ElideMiddle
                                }
                            }
                            StyledText {
                                text: modelData.status || ""
                                font.pixelSize: Theme.fontSizeSmall
                                textFormat: Text.PlainText
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: list.currentIndex = index
                            onClicked: root.choose(index)
                        }
                        SyncshellToolTip {
                            anchors.fill: parent
                            text: modelData.help || ""
                        }
                    }
                }
            }
        }
    }
}
