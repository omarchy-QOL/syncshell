pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import "UiConstants.js" as UiConstants

Item {
    id: root

    property string value: ""
    property string notice: "ID copied"
    property string text: ""
    property string helpText: "Copy ID"
    property string variant: "button"
    property real size: Style.spacing.controlHeight
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family
    property int fontSize: Style.font.caption
    property int iconSize: Style.font.caption
    property int horizontalPadding: Style.space(4)
    property int verticalPadding: 0
    property bool hasCursor: false
    property var controller

    signal hovered(bool isHovered)

    function activate() {
        if (!root.enabled || !root.value)
            return false;
        root.copy();
        return true;
    }

    function copy() {
        if (!value)
            return;
        Quickshell.execDetached(["wl-copy", "--", value]);
        if (controller)
            controller.showNotice(notice, UiConstants.BRIEF_NOTICE_VISIBLE_MS);
    }

    readonly property Item loadedButton: buttonLoader.item as Item

    implicitWidth: root.loadedButton ? root.loadedButton.implicitWidth : root.size
    implicitHeight: root.loadedButton ? root.loadedButton.implicitHeight : root.size

    Loader {
        id: buttonLoader
        anchors.fill: parent
        sourceComponent: root.variant === "panel" ? panelButton : regularButton
    }

    Component {
        id: panelButton

        TooltipPanelActionButton {
            size: root.size
            iconText: "󰆏"
            helpText: root.helpText
            bordered: true
            hasCursor: root.hasCursor
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: root.fontSize
            onHovered: function (hovered) {
                root.hovered(hovered);
            }
            onClicked: root.copy()
        }
    }

    Component {
        id: regularButton

        TooltipButton {
            text: root.text
            iconText: "󰆏"
            helpText: root.helpText
            bordered: true
            hasCursor: root.hasCursor
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: root.fontSize
            iconSize: root.iconSize
            horizontalPadding: root.horizontalPadding
            verticalPadding: root.verticalPadding
            onHovered: function (hovered) {
                root.hovered(hovered);
            }
            onClicked: root.copy()
        }
    }
}
