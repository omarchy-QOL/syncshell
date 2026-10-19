import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

MaterialSymbol {
    property string selection: "empty"
    iconSize: 18
    Layout.preferredWidth: 20
    Layout.preferredHeight: 20
    color: Appearance.colors.colPrimary
    text: selection === "mixed" ? "indeterminate_check_box" : selection === "checked" ? "check_box" : "check_box_outline_blank"
}
