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
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            var focused = window.activeFocusItem;
            switch (root.step++) {
            case 0:
                dropdown.open();
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
                var children = root.searchInput.parent.parent.children;
                for (var i = 0; i < children.length; i++) {
                    if (typeof children[i].itemAtIndex === "function")
                        input.mouseClick(children[i].itemAtIndex(1));
                }
                break;
            case 14:
                root.check(!dropdown.popupOpen && dropdown.value === "work-notes", "click selects its row immediately without confirmation");
                root.check(dropdown.matchesSearch("WorkFlow", " WKFL ") && !dropdown.matchesSearch("workflow", "fwk"), "case and letter order");
                dropdown.searchable = false;
                dropdown.open();
                break;
            case 15:
                input.keyClick(Qt.Key_Slash);
                break;
            default:
                root.check(dropdown.popupOpen && root.propertyValue(window.activeFocusItem, "text") === undefined, "ordinary dropdowns do not enter search");
                input.keyClick(Qt.Key_Escape);
                root.check(!dropdown.popupOpen, "ordinary dropdown escape");
                console.log("dropdown search tests passed");
                Qt.quit();
            }
        }
    }
}
