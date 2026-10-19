import QtQuick
import qs.modules.waffle.looks

QtObject {
    readonly property string family: "waffle"
    readonly property color background: Looks.colors.bgPanelFooterBackground
    readonly property color surface: Looks.colors.bgPanelBody
    readonly property color foreground: Looks.colors.fg
    readonly property color muted: Looks.colors.subfg
    readonly property color accent: Looks.colors.accent
    readonly property color danger: Looks.colors.danger
    readonly property int margin: 12
    readonly property int spacing: 8
    readonly property int panelWidth: 410
    readonly property int formWidth: 340
    readonly property var palette: ({
            mode: Looks.dark ? "dark" : "light",
            background: rgb(Looks.colors.bg0Base),
            surface: rgb(Looks.colors.bgPanelBodyBase),
            surfaceVariant: rgb(Looks.colors.bg2Base),
            foreground: rgb(foreground),
            muted: rgb(muted),
            accent: rgb(accent),
            success: rgb(Looks.colors.accent),
            warning: rgb(Looks.colors.warning),
            danger: rgb(danger),
            border: rgb(Looks.colors.bg0Border),
            info: rgb(Looks.colors.link)
        })
    function colorFor(role) {
        return role === "danger" ? danger : role === "warning" ? palette.warning
            : role === "success" ? palette.success : role === "accent" ? accent
            : role === "muted" ? muted : foreground;
    }
    readonly property int controlHeight: 34
    readonly property int menuWidth: 340
    function rgb(value) {
        var color = Qt.color(value);
        return "#" + [color.r, color.g, color.b].map(channel => Math.round(channel * 255).toString(16).padStart(2, "0")).join("");
    }
    property Component toolTip: NativeToolTip {}
    property Component progress: WProgressBar {}
    property Component busyIndicator: WIndeterminateProgressBar {}
    property Component iconButton: NativeIconButton {}
    property Component list: WListView {
        clip: true
    }
    property Component choice: NativeChoice {}
    property Component button: NativeButton {}
    property Component field: WTextField {
        selectByMouse: true
    }
    property Component text: WText {
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    property Component toggle: WSwitch {}
    property Component tabs: NativeTabs {}
    property Component scrollBar: WScrollBar {}
    property Component surfaceComponent: NativeSurface {}
}
