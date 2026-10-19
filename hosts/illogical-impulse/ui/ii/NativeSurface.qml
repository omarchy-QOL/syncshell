import QtQuick
import qs.modules.common
import qs.modules.common.widgets

StyledRectangle {
    property real footerHeight: 0
    color: Appearance.colors.colLayer0
    radius: Appearance.rounding.large
    StyledRectangularShadow {
        target: parent
    }
}
