pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Item {
    id: root

    required property var controller
    required property int resultCount
    required property int totalCount
    property color foreground: Color.popups.text
    property color background: Color.popups.background
    property color popupBorder: Color.popups.border
    property color accent: Color.accent
    property color urgent: Color.urgent
    property string fontFamily: Style.font.family
    readonly property bool popupOpen: popup.opened
    readonly property bool filtersDefault: controller.folderShowReady && controller.folderShowActive && controller.folderShowErrors && controller.folderShowPaused && controller.folderShowUnknown
    readonly property bool viewDefault: filtersDefault && controller.folderSortMode === "name"
    readonly property var filterRows: [
        {
            key: "all",
            label: "All",
            help: "Show every folder"
        },
        {
            key: "ready",
            label: "Ready",
            help: "Synced or newly linked"
        },
        {
            key: "active",
            label: "Active",
            help: "Currently syncing or scanning"
        },
        {
            key: "errors",
            label: "Errors",
            help: "Needs attention"
        },
        {
            key: "paused",
            label: "Paused",
            help: "Syncing is paused"
        },
        {
            key: "unknown",
            label: "Unknown",
            help: "Current status is unavailable"
        }
    ]
    readonly property var sortRows: [
        {
            key: "name",
            label: "Name A-Z",
            help: "Sort folder names alphabetically"
        },
        {
            key: "active",
            label: "Active first",
            help: "Put syncing and scanning folders first"
        },
        {
            key: "errors",
            label: "Errors first",
            help: "Put folders needing attention first"
        }
    ]
    readonly property var popupBorderSpec: Border.localOrSurfaceSpec("popups", "border", popupBorder, Color.popups.border, Style.normalBorderWidth)
    property int keyboardIndex: 0

    signal closed

    function open() {
        popup.open();
    }
    function close() {
        popup.close();
    }
    function toggle() {
        popup.opened ? popup.close() : popup.open();
    }
    function moveKeyboardCursor(dx, dy) {
        if (dx !== 0 && keyboardIndex < filterRows.length) {
            var rowStart = Math.floor(keyboardIndex / 2) * 2;
            keyboardIndex = rowStart + ((keyboardIndex - rowStart + (dx > 0 ? 1 : -1) + 2) % 2);
        } else if (dy > 0) {
            if (keyboardIndex < filterRows.length - 2)
                keyboardIndex += 2;
            else if (keyboardIndex < filterRows.length)
                keyboardIndex = filterRows.length;
            else if (keyboardIndex < filterRows.length + sortRows.length)
                keyboardIndex++;
            else
                keyboardIndex = 0;
        } else if (dy < 0) {
            if (keyboardIndex < 2)
                keyboardIndex = filterRows.length + sortRows.length;
            else if (keyboardIndex < filterRows.length)
                keyboardIndex -= 2;
            else if (keyboardIndex === filterRows.length)
                keyboardIndex = filterRows.length - 2;
            else
                keyboardIndex--;
        }
    }
    function activateKeyboardChoice() {
        if (keyboardIndex < filterRows.length) {
            activateFilter(filterRows[keyboardIndex].key);
        } else if (keyboardIndex < filterRows.length + sortRows.length) {
            controller.folderSortMode = sortRows[keyboardIndex - filterRows.length].key;
        } else
            controller.resetFolderView();
    }
    function allGroupsEnabled() {
        return filtersDefault;
    }
    function someGroupsEnabled() {
        return controller.folderShowReady || controller.folderShowActive || controller.folderShowErrors || controller.folderShowPaused || controller.folderShowUnknown;
    }
    function filterChecked(key) {
        if (key === "all")
            return allGroupsEnabled();
        return controller.folderGroupVisible(key);
    }
    function filterMixed(key) {
        return key === "all" && someGroupsEnabled() && !allGroupsEnabled();
    }
    function activateFilter(key) {
        if (key === "all")
            controller.setAllFolderGroups(!allGroupsEnabled());
        else
            controller.setFolderGroupVisible(key, !controller.folderGroupVisible(key));
    }

    component ChoiceRow: Item {
        id: choice

        required property string label
        required property string helpText
        required property int navigationIndex
        property bool checked: false
        property bool mixed: false
        property bool radio: false
        readonly property bool hasCursor: root.keyboardIndex === navigationIndex

        signal activated

        height: Style.spacing.controlHeight

        Rectangle {
            anchors.fill: parent
            color: choiceHover.hovered || choice.hasCursor ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"
            radius: Style.cornerRadius
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.spacing.controlPaddingX
            anchors.rightMargin: Style.spacing.controlPaddingX
            spacing: Style.spacing.controlGap

            BorderSurface {
                id: indicator
                width: Style.space(16)
                height: width
                anchors.verticalCenter: parent.verticalCenter
                radius: choice.radio ? width / 2 : Math.max(2, Style.cornerRadius / 2)
                color: !choice.radio && (choice.checked || choice.mixed) ? Style.selectedFillFor(root.foreground, root.accent) : "transparent"
                borderSpec: choice.radio ? Border.controlSpec("normal", root.foreground, root.accent) : choice.checked || choice.mixed ? Border.controlSpec("selected", root.foreground, root.accent) : Border.controlSpec("normal", root.foreground, root.accent)

                Rectangle {
                    anchors.centerIn: parent
                    visible: choice.radio && choice.checked
                    width: Style.space(7)
                    height: width
                    radius: width / 2
                    color: Style.selectedStateColor(root.foreground, root.accent)
                }

                Text {
                    anchors.centerIn: parent
                    visible: !choice.radio && (choice.checked || choice.mixed)
                    text: choice.mixed ? "-" : "✓"
                    color: Style.selectedStateColor(root.foreground, root.accent)
                    font.family: root.fontFamily
                    font.pixelSize: Math.round(indicator.height * 0.85)
                    font.bold: true
                }
            }

            Text {
                width: parent.width - indicator.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: choice.label
                textFormat: Text.PlainText
                color: choiceHover.hovered || choice.hasCursor ? Style.hoverStateColor(root.foreground, root.accent) : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
            }
        }

        HoverHandler {
            id: choiceHover
            onHoveredChanged: if (hovered)
                root.keyboardIndex = choice.navigationIndex
        }
        SyncshellToolTip {
            visible: choiceHover.hovered
            text: choice.helpText
            fontFamily: root.fontFamily
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.activated()
        }
    }

    implicitWidth: accessoryRow.implicitWidth
    implicitHeight: accessoryRow.implicitHeight

    Row {
        id: accessoryRow
        height: Style.spacing.controlHeight
        spacing: Style.spacing.controlGap

        SquareActionButton {
            glyph: "\uf1de"
            helpText: "Filter and sort folders"
            selected: !root.viewDefault
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.toggle()
        }

        Text {
            visible: root.totalCount > 0 && root.resultCount < root.totalCount
            anchors.verticalCenter: parent.verticalCenter
            text: "(" + root.resultCount + " of " + root.totalCount + ")"
            textFormat: Text.PlainText
            color: Color.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
        }
    }

    Popup {
        id: popup
        x: root.width - width
        y: root.height + Style.spacing.xxs
        width: Style.spacing.dropdownWidth
        implicitHeight: content.implicitHeight + topPadding + bottomPadding
        padding: Style.space(8)
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        background: BorderSurface {
            color: root.background
            borderSpec: root.popupBorderSpec
            radius: Style.cornerRadius
        }

        onOpened: {
            root.keyboardIndex = 0;
            content.forceActiveFocus();
        }
        onClosed: root.closed()

        contentItem: Column {
            id: content
            spacing: Style.space(6)

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function (event) {
                var key = event.text.toLowerCase();
                if (event.key === Qt.Key_Escape || key === "q")
                    popup.close();
                else if (event.key === Qt.Key_Down || key === "j")
                    root.moveKeyboardCursor(0, 1);
                else if (event.key === Qt.Key_Up || key === "k")
                    root.moveKeyboardCursor(0, -1);
                else if (event.key === Qt.Key_Right || key === "l")
                    root.moveKeyboardCursor(1, 0);
                else if (event.key === Qt.Key_Left || key === "h")
                    root.moveKeyboardCursor(-1, 0);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                    root.activateKeyboardChoice();
                else
                    return;
                event.accepted = true;
            }

            InlineFormHeader {
                width: parent.width
                title: "VIEW OPTIONS"
                foreground: root.foreground
                cancelColor: root.urgent
                fontFamily: root.fontFamily
                onCanceled: popup.close()
            }

            PanelSectionHeader {
                text: "SHOW"
                foreground: root.foreground
                fontFamily: root.fontFamily
            }

            Grid {
                id: filterGrid
                width: parent.width
                columns: 2
                columnSpacing: Style.space(6)
                rowSpacing: Style.spacing.labelGap

                Repeater {
                    model: root.filterRows

                    delegate: ChoiceRow {
                        required property var modelData
                        required property int index
                        width: (filterGrid.width - filterGrid.columnSpacing) / 2
                        navigationIndex: index
                        label: modelData.label
                        helpText: modelData.help
                        checked: root.filterChecked(modelData.key)
                        mixed: root.filterMixed(modelData.key)
                        onActivated: root.activateFilter(modelData.key)
                    }
                }
            }

            PanelSeparator {
                foreground: root.foreground
            }

            PanelSectionHeader {
                text: "SORT"
                foreground: root.foreground
                fontFamily: root.fontFamily
            }

            Column {
                width: parent.width
                spacing: Style.spacing.labelGap

                Repeater {
                    model: root.sortRows

                    delegate: ChoiceRow {
                        required property var modelData
                        required property int index
                        width: parent.width
                        navigationIndex: root.filterRows.length + index
                        label: modelData.label
                        helpText: modelData.help
                        checked: root.controller.folderSortMode === modelData.key
                        radio: true
                        onActivated: root.controller.folderSortMode = modelData.key
                    }
                }
            }

            PanelSeparator {
                foreground: root.foreground
            }

            Item {
                width: parent.width
                height: resetButton.implicitHeight

                TooltipButton {
                    id: resetButton
                    anchors.right: parent.right
                    text: "Reset defaults"
                    helpText: "Show all folders\nand sort by name"
                    bordered: true
                    hasCursor: root.keyboardIndex === root.filterRows.length + root.sortRows.length
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    fontSize: Style.font.body
                    horizontalPadding: Style.space(6)
                    verticalPadding: Style.space(3)
                    onHovered: function (hovered) {
                        if (hovered)
                            root.keyboardIndex = root.filterRows.length + root.sortRows.length;
                    }
                    onClicked: root.controller.resetFolderView()
                }
            }
        }
    }
}
