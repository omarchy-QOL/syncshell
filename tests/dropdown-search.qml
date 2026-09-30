import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Window
import QtTest
import Quickshell
import "../hosts/omarchy/ui"

ShellRoot {
    id: root
    property int step: 0
    property QQC.TextField searchInput

    VisualPause { id: inspection }

    Window {
        id: window
        visible: true
        width: 420
        height: 420

        SyncshellDropdown {
            id: dropdown
            x: 20
            y: 20
            width: 360
            showLabel: false
            searchable: true
            value: "docs"
            options: ["workflow", "work-notes", "docs", "project-k"]
            searchHeaderAccessory: Component {
                Item {
                    property bool popupOpen: false
                    implicitWidth: 1
                    function open() {
                        popupOpen = true;
                    }
                    function close() {
                        popupOpen = false;
                    }
                }
            }
        }

        TestCase {
            id: input
            when: false
        }
    }

    function check(condition, message) {
        if (condition)
            return;
        console.error(message);
        Qt.exit(1);
        throw new Error(message);
    }

    function propertyValue(item, name) {
        return item ? item[name] : undefined;
    }

    Timer {
        id: scenarioTimer
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            var focused = window.activeFocusItem;
            switch (root.step++) {
            case 0:
                root.check(dropdown.activate(), "dropdown accepts panel activation");
                break;
            case 1:
                root.check(dropdown.popupOpen, "dropdown opens");
                input.keyClick(Qt.Key_Slash);
                break;
            case 2:
                root.searchInput = focused as QQC.TextField;
                root.check(root.searchInput && root.searchInput.text === "" && root.searchInput.placeholderText === "", "slash enters empty search and hides hint");
                input.keyClick(Qt.Key_W);
                input.keyClick(Qt.Key_K);
                input.keyClick(Qt.Key_F);
                input.keyClick(Qt.Key_L);
                break;
            case 3:
                root.check(dropdown.matchingOptions.join() === "workflow", "fuzzy matching");
                input.keyClick(Qt.Key_Escape);
                break;
            case 4:
                root.check(dropdown.popupOpen && dropdown.matchingOptions.length === 4, "first escape clears search and keeps dropdown open");
                root.check(root.propertyValue(focused, "placeholderText") === undefined, "search loses focus");
                root.check(root.searchInput.placeholderText === "To search press '/'", "inactive search shows its hint");
                input.keyClick(Qt.Key_Escape);
                break;
            case 5:
                root.check(!dropdown.popupOpen && dropdown.value === "docs", "second escape closes without selection");
                dropdown.open();
                break;
            case 6:
                input.keyClick(Qt.Key_Slash);
                input.keyClick(Qt.Key_Z);
                break;
            case 7:
                root.check(dropdown.matchingOptions.length === 0, "empty results");
                input.keyClick(Qt.Key_Return);
                break;
            case 8:
                root.check(dropdown.popupOpen && dropdown.value === "docs", "enter cannot select an empty result");
                input.keyClick(Qt.Key_Backspace);
                input.keyClick(Qt.Key_P);
                input.keyClick(Qt.Key_J);
                input.keyClick(Qt.Key_K);
                break;
            case 9:
                root.check(dropdown.matchingOptions.join() === "project-k", "j and k remain text while searching");
                input.keyClick(Qt.Key_Return);
                break;
            case 10:
                root.check(!dropdown.popupOpen && dropdown.value === "project-k", "enter selects the filtered result immediately");
                dropdown.open();
                break;
            case 11:
                input.mouseClick(root.searchInput);
                break;
            case 12:
                root.check(focused === root.searchInput && root.searchInput.placeholderText === "", "click enters search and hides hint");
                input.keyClick(Qt.Key_W);
                input.keyClick(Qt.Key_K);
                break;
            case 13:
                root.check(dropdown.matchingOptions.length === 2, "multiple fuzzy results");
                input.mouseClick(dropdown.optionItemAt(1));
                break;
            case 14:
                root.check(!dropdown.popupOpen && dropdown.value === "work-notes", "click selects its row immediately without confirmation");
                root.check(dropdown.matchesSearch("WorkFlow", " WKFL ") && !dropdown.matchesSearch("workflow", "fwk"), "case and letter order");
                dropdown.open();
                break;
            case 15:
                dropdown.headerAccessoryItem.popupOpen = true;
                input.keyClick(Qt.Key_Escape);
                break;
            case 16:
                root.check(dropdown.popupOpen && !dropdown.headerAccessoryOpen, "escape closes the header accessory first");
                input.keyClick(Qt.Key_Escape);
                break;
            case 17:
                root.check(!dropdown.popupOpen, "escape closes the dropdown after the accessory");
                dropdown.open();
                break;
            case 18:
                input.keyClick(Qt.Key_L);
                break;
            case 19:
                root.check(dropdown.popupOpen && dropdown.headerAccessoryOpen, "l opens the header accessory");
                input.keyClick(Qt.Key_Q);
                break;
            case 20:
                root.check(dropdown.popupOpen && !dropdown.headerAccessoryOpen, "q closes the header accessory first");
                input.keyClick(Qt.Key_Q);
                break;
            case 21:
                root.check(!dropdown.popupOpen, "q closes the dropdown after the accessory");
                dropdown.searchable = false;
                dropdown.open();
                input.keyClick(Qt.Key_Slash);
                break;
            default:
                root.check(dropdown.popupOpen && root.propertyValue(window.activeFocusItem, "text") === undefined, "ordinary dropdowns do not enter search");
                input.keyClick(Qt.Key_Escape);
                root.check(!dropdown.popupOpen, "ordinary dropdown escape");
                console.log("dropdown search tests passed");
                Qt.quit();
                return;
            }
            inspection.pause(({
                0: "dropdown open",
                2: "fuzzy search: wkfl matches workflow",
                6: "search with no results",
                8: "j and k typed into search",
                12: "mouse search with two matching rows",
                18: "header accessory open",
                21: "ordinary dropdown without search"
            })[root.step - 1], function () { scenarioTimer.start(); });
        }
    }
}
