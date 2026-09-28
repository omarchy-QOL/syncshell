pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Themed single-select dropdown. Trigger row paints with the kit's focus
// chrome; the popup anchors below and uses Color.popups.background +
// Color.popups.border so it reads as a panel surface rather than the
// platform-native ComboBox look.
//
// `options` accepts either a plain string[] or an array of
// { value, label } objects (label is what we render; value is what we
// emit). Mixing is fine — each row is interpreted independently.
//
// Keyboard: Tab to focus the trigger, Enter/Space opens, Esc closes,
// j/k or Up/Down walks options inside the open popup, Enter selects.
Item {
    id: root

    property string label: ""
    property string value: ""
    property string displayText: ""
    property var options: []
    property bool searchable: false
    property Component searchHeaderAccessory: null
    readonly property string currentText: displayText !== "" ? displayText : currentLabel()
    readonly property var matchingOptions: searchable ? options.filter(function (option) {
        return matchesSearch(optionLabel(option), searchField.text);
    }) : options

    property color foreground: Color.popups.text
    property color background: Color.popups.background
    property color popupBorder: Color.popups.border
    property color accent: Color.accent
    readonly property var popupBorderSpec: Border.localOrSurfaceSpec("popups", "border", popupBorder, Color.popups.border, Style.normalBorderWidth)
    property string fontFamily: Style.font.family
    property int rowHeight: Style.spacing.controlHeight
    property int popupRowHeight: Style.spacing.popupRowHeight
    property bool showLabel: true
    property bool interactive: true
    property bool statusVisible: false
    property color statusColor: "transparent"
    property string statusHelpText: ""
    property string helpText: ""

    // Panel-cursor flag. When true, the trigger renders the shared
    // hover-cursor state. Active Qt focus defaults to the same visuals.
    // Emits `hovered(bool)` on pointer enter/leave so the panel can keep
    // its cursor state in sync with the mouse.
    property bool hasCursor: false

    // popupOpen + open()/close()/toggle() let a parent panel know when the
    // dropdown owns keys (its embedded ListView is active) and suspend its
    // own keyCatcher so j/k inside the popup don't double-drive the panel
    // cursor.
    readonly property bool popupOpen: popup.opened
    readonly property var headerAccessoryItem: searchAccessoryLoader.item
    readonly property bool headerAccessoryOpen: headerAccessoryItem ? !!headerAccessoryItem.popupOpen : false
    function open() {
        if (interactive)
            popup.open();
    }
    function close() {
        popup.close();
    }
    function toggle() {
        popup.opened ? popup.close() : popup.open();
    }
    function focusResults() {
        optionList.forceActiveFocus();
    }
    function optionItemAt(index) {
        return optionList.itemAtIndex(index);
    }
    function closeHeaderAccessory() {
        if (headerAccessoryItem && typeof headerAccessoryItem.close === "function") {
            headerAccessoryItem.close();
        }
    }

    signal changed(string value)
    signal hovered(bool isHovered)

    function optionValue(o) {
        return (o && typeof o === "object") ? String(o.value) : String(o);
    }
    function optionLabel(o) {
        return (o && typeof o === "object") ? String(o.label) : String(o);
    }
    function optionStatusVisible(o) {
        return o && typeof o === "object" && !!o.statusVisible;
    }
    function optionStatusColor(o) {
        return optionStatusVisible(o) ? o.statusColor : "transparent";
    }
    function optionStatusHelpText(o) {
        return optionStatusVisible(o) ? String(o.statusHelpText || "") : "";
    }
    function currentLabel() {
        for (var i = 0; i < options.length; i++) {
            if (optionValue(options[i]) === value)
                return optionLabel(options[i]);
        }
        return value;
    }

    function matchesSearch(label, query) {
        var text = label.toLowerCase();
        var needle = query.trim().toLowerCase();
        var position = 0;
        for (var i = 0; i < needle.length; i++) {
            position = text.indexOf(needle[i], position);
            if (position < 0)
                return false;
            position++;
        }
        return true;
    }

    implicitWidth: Style.spacing.dropdownWidth
    implicitHeight: showLabel && label !== "" ? rowHeight + Style.spacing.huge : rowHeight

    Column {
        anchors.fill: parent
        spacing: Style.spacing.labelGap

        Text {
            textFormat: Text.PlainText
            visible: root.showLabel && root.label !== ""
            text: root.label
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
        }

        BorderSurface {
            id: trigger
            width: parent.width
            height: root.rowHeight
            radius: Style.cornerRadius

            readonly property bool _focused: trigger.activeFocus
            readonly property bool _hot: triggerHover.hovered || root.hasCursor
            readonly property var _borderSpec: Border.controlSpec(trigger._focused ? "focus" : (trigger._hot ? "hover-cursor" : "normal"), root.foreground, root.accent)

            color: Style.controlFill(trigger._focused, trigger._hot, root.foreground, root.accent)
            borderSpec: _borderSpec

            activeFocusOnTab: root.interactive

            HoverHandler {
                id: triggerHover
                onHoveredChanged: root.hovered(hovered)
            }
            SyncshellToolTip {
                visible: triggerHover.hovered && !popup.opened && root.helpText !== ""
                text: root.helpText
                fontFamily: root.fontFamily
            }

            Keys.onPressed: function (event) {
                if (!root.interactive)
                    return;
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
                    popup.opened ? popup.close() : popup.open();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape && popup.opened) {
                    popup.close();
                    event.accepted = true;
                }
            }

            Text {
                textFormat: Text.PlainText
                anchors.left: parent.left
                anchors.right: root.statusVisible ? statusDot.left : chevron.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: trigger.borderLeft + Style.spacing.controlPaddingX
                anchors.rightMargin: trigger.borderRight + Style.spacing.md
                text: root.currentText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
            }

            Rectangle {
                id: statusDot
                visible: root.statusVisible
                anchors.right: chevron.left
                anchors.rightMargin: Style.spacing.controlGap
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(7)
                height: width
                radius: width / 2
                color: root.statusColor

                HoverHandler {
                    id: statusHover
                }
                SyncshellToolTip {
                    visible: statusHover.hovered && root.statusHelpText !== ""
                    text: root.statusHelpText
                    fontFamily: root.fontFamily
                }
            }

            Text {
                id: chevron
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: trigger.borderRight + Style.spacing.controlGap
                text: "󰅀"
                color: Qt.darker(root.foreground, 1.2)
                opacity: root.interactive ? 1 : 0.4
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.interactive
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    trigger.forceActiveFocus();
                    popup.opened ? popup.close() : popup.open();
                }
            }

            Popup {
                id: popup
                x: 0
                y: trigger.height + Style.spacing.xxs
                width: trigger.width
                implicitHeight: searchHeader.height + Math.min(Math.max(1, root.matchingOptions.length) * root.popupRowHeight + Math.max(0, root.matchingOptions.length - 1) * Style.spacing.labelGap + Style.spacing.xxs, root.popupRowHeight * 8 + 7 * Style.spacing.labelGap + Style.spacing.xxs)
                padding: Style.spacing.hairline
                leftPadding: Border.left(root.popupBorderSpec) + Style.spacing.hairline
                rightPadding: Border.right(root.popupBorderSpec) + Style.spacing.hairline
                topPadding: Border.top(root.popupBorderSpec) + Style.spacing.hairline
                bottomPadding: Border.bottom(root.popupBorderSpec) + Style.spacing.hairline
                focus: true
                closePolicy: Popup.CloseOnPressOutsideParent | ((searchField.activeFocus || root.headerAccessoryOpen) ? 0 : Popup.CloseOnEscape)

                function handleKey(event, editing) {
                    if (event.key === Qt.Key_Escape) {
                        if (root.headerAccessoryOpen) {
                            root.closeHeaderAccessory();
                            optionList.forceActiveFocus();
                        } else if (editing) {
                            searchField.text = "";
                            optionList.forceActiveFocus();
                        } else
                            popup.close();
                    } else if (!editing && root.searchable && event.text === "/") {
                        searchField.forceActiveFocus();
                    } else if (event.key === Qt.Key_Down || (!editing && event.text === "j")) {
                        optionList.currentIndex = Math.min(optionList.count - 1, optionList.currentIndex + 1);
                    } else if (event.key === Qt.Key_Up || (!editing && event.text === "k")) {
                        optionList.currentIndex = Math.max(0, optionList.currentIndex - 1);
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        optionList.selectCurrent();
                    } else
                        return;
                    event.accepted = true;
                }

                background: BorderSurface {
                    color: root.background
                    borderSpec: root.popupBorderSpec
                    radius: Style.cornerRadius
                }

                onOpened: {
                    searchField.text = "";
                    var selectedIndex = optionList.indexOfValue(root.value);
                    optionList.currentIndex = selectedIndex >= 0 ? selectedIndex : (optionList.count > 0 ? 0 : -1);
                    optionList.forceActiveFocus();
                }
                onClosed: {
                    root.closeHeaderAccessory();
                    searchField.text = "";
                }

                contentItem: Item {
                    Item {
                        id: searchHeader
                        width: parent.width
                        height: root.searchable ? root.popupRowHeight + Style.spacing.md : 0
                        visible: root.searchable

                        Row {
                            anchors.fill: parent
                            anchors.margins: Style.spacing.xxs
                            spacing: searchAccessoryLoader.visible ? Style.spacing.controlGap : 0

                            TextField {
                                id: searchField
                                width: parent.width - searchAccessoryLoader.width - parent.spacing
                                height: parent.height
                                placeholderText: activeFocus ? "" : "To search press '/'"
                                foreground: root.foreground
                                accent: root.accent
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.body
                                onTextChanged: optionList.currentIndex = 0
                                Keys.priority: Keys.BeforeItem
                                Keys.onPressed: function (event) {
                                    popup.handleKey(event, true);
                                }
                            }

                            Loader {
                                id: searchAccessoryLoader
                                visible: root.searchHeaderAccessory !== null
                                width: visible && root.headerAccessoryItem ? root.headerAccessoryItem.implicitWidth : 0
                                height: parent.height
                                sourceComponent: root.searchHeaderAccessory
                            }
                        }
                    }

                    Text {
                        visible: root.matchingOptions.length === 0
                        anchors.top: searchHeader.bottom
                        width: parent.width
                        height: root.popupRowHeight
                        text: "No matches"
                        textFormat: Text.PlainText
                        color: Qt.darker(root.foreground, 1.5)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    ListView {
                        id: optionList
                        anchors.top: searchHeader.bottom
                        anchors.bottom: parent.bottom
                        width: parent.width
                        spacing: Style.spacing.labelGap

                        Keys.priority: Keys.BeforeItem
                        Keys.onPressed: function (event) {
                            popup.handleKey(event, false);
                        }
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.matchingOptions
                        currentIndex: -1

                        function indexOfValue(v) {
                            for (var i = 0; i < root.matchingOptions.length; i++)
                                if (root.optionValue(root.matchingOptions[i]) === v)
                                    return i;
                            return -1;
                        }

                        function selectCurrent() {
                            if (currentIndex < 0 || currentIndex >= root.matchingOptions.length)
                                return;
                            var v = root.optionValue(root.matchingOptions[currentIndex]);
                            root.value = v;
                            root.changed(v);
                            popup.close();
                        }

                        delegate: Rectangle {
                            id: option

                            required property var modelData
                            required property int index
                            width: optionList.width
                            height: root.popupRowHeight
                            color: option.index === optionList.currentIndex ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"

                            Text {
                                textFormat: Text.PlainText
                                anchors.left: parent.left
                                anchors.right: optionStatus.visible ? optionStatus.left : parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Style.spacing.controlPaddingX
                                anchors.rightMargin: Style.spacing.controlPaddingX
                                text: root.optionLabel(option.modelData)
                                color: option.index === optionList.currentIndex ? Style.hoverStateColor(root.foreground, root.accent) : root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.body
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                id: optionStatus
                                visible: root.optionStatusVisible(option.modelData)
                                anchors.right: parent.right
                                anchors.rightMargin: Style.spacing.controlPaddingX
                                anchors.verticalCenter: parent.verticalCenter
                                width: Style.space(7)
                                height: width
                                radius: width / 2
                                color: root.optionStatusColor(option.modelData)

                                HoverHandler {
                                    id: optionStatusHover
                                }
                                SyncshellToolTip {
                                    visible: optionStatusHover.hovered && root.optionStatusHelpText(option.modelData) !== ""
                                    text: root.optionStatusHelpText(option.modelData)
                                    fontFamily: root.fontFamily
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: optionList.currentIndex = option.index
                                onClicked: {
                                    optionList.currentIndex = option.index;
                                    optionList.selectCurrent();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
