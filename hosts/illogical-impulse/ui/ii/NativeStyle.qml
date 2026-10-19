import QtQuick
import qs.modules.common
import qs.modules.common.widgets

QtObject {
    readonly property string family: "ii"
    readonly property color background: Appearance.colors.colLayer0
    readonly property color surface: Appearance.colors.colLayer1
    readonly property color foreground: Appearance.colors.colOnLayer0
    readonly property color muted: Appearance.colors.colSubtext
    readonly property color accent: Appearance.colors.colPrimary
    readonly property color danger: Appearance.m3colors.m3error
    readonly property int margin: 16
    readonly property int spacing: 10
    readonly property int panelWidth: 440
    readonly property int formWidth: 360
    readonly property var palette: ({
            mode: Appearance.m3colors.darkmode ? "dark" : "light",
            background: rgb(background),
            surface: rgb(surface),
            surfaceVariant: rgb(Appearance.colors.colLayer2),
            foreground: rgb(foreground),
            muted: rgb(muted),
            accent: rgb(accent),
            success: rgb(Appearance.colors.colPrimary),
            warning: rgb(Appearance.m3colors.m3tertiary),
            danger: rgb(danger),
            border: rgb(Appearance.colors.colOutlineVariant),
            info: rgb(Appearance.colors.colSecondary)
        })
    function colorFor(role) {
        return role === "danger" ? danger : role === "warning" ? palette.warning
            : role === "success" ? palette.success : role === "accent" ? accent
            : role === "muted" ? muted : foreground;
    }
    readonly property int controlHeight: 40
    readonly property int menuWidth: 360
    function rgb(value) {
        var color = Qt.color(value);
        return "#" + [color.r, color.g, color.b].map(channel => Math.round(channel * 255).toString(16).padStart(2, "0")).join("");
    }
    property Component toolTip: NativeToolTip {}
    property Component progress: StyledProgressBar {}
    property Component busyIndicator: StyledIndeterminateProgressBar {}
    property Component iconButton: NativeIconButton {}
    property Component list: StyledListView {
        clip: true
    }
    property Component choice: NativeChoice {}
    property Component button: NativeButton {}
    property Component field: MaterialTextField {
        selectByMouse: true
    }
    property Component text: StyledText {
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    property Component toggle: StyledSwitch {}
    property Component tabs: NativeTabs {}
    property Component scrollBar: StyledScrollBar { implicitHeight: 40 }
    property Component surfaceComponent: NativeSurface {}
}
