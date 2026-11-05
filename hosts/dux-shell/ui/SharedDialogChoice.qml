import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Omarchy's forced choice when the saved preference and systemd disagree.
FocusScope {
    id: root
    property var controller: null
    readonly property var decision: controller ? controller.drift : null
    // 0 is the first choice, the preferred one.
    property int selected: 0
    signal dismissed
    implicitHeight: content.implicitHeight
    focus: true
    function selectFirst() {
        selected = 0;
        firstButton.forceActiveFocus(Qt.TabFocusReason);
    }
    function activate(index) {
        if (decision)
            controller.chooseDrift(index === 0 ? decision.first : decision.second);
    }
    Component.onCompleted: selectFirst()
    Keys.onPressed: event => {
        if (event.isAutoRepeat || controller.busy) {
            event.accepted = true;
            return;
        }
        switch (event.key) {
        case Qt.Key_Escape:
        case Qt.Key_Q:
            dismissed();
            break;
        case Qt.Key_Up:
        case Qt.Key_Down:
            selected = event.key === Qt.Key_Up ? 0 : 1;
            (selected === 0 ? firstButton : secondButton).forceActiveFocus(Qt.TabFocusReason);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            activate(selected);
            break;
        default:
            break;
        }
        event.accepted = true;
    }
    Column {
        id: content
        width: parent.width
        spacing: Theme.spacingM
        enabled: !root.controller || !root.controller.busy
        StyledText {
            width: parent.width
            text: root.decision ? root.decision.message : ""
            textFormat: Text.PlainText
            color: Theme.onSurface
            wrapMode: Text.Wrap
        }
        DButton {
            id: firstButton
            width: parent.width
            maximumWidth: width
            text: root.decision ? root.decision.first.label : ""
            backgroundColor: Theme.primary
            textColor: Theme.onPrimary
            KeyNavigation.tab: secondButton
            onActiveFocusChanged: if (activeFocus)
                root.selected = 0
            onClicked: root.activate(0)
        }
        DButton {
            id: secondButton
            width: parent.width
            maximumWidth: width
            text: root.decision ? root.decision.second.label : ""
            backgroundColor: Theme.secondaryContainer
            textColor: Theme.onSecondaryContainer
            KeyNavigation.tab: firstButton
            onActiveFocusChanged: if (activeFocus)
                root.selected = 1
            onClicked: root.activate(1)
        }
    }
}
