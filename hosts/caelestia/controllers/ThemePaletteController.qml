pragma ComponentBehavior: Bound

import QtQuick
import qs.services

QtObject {
    readonly property var palette: ({
            mode: Colours.light ? "light" : "dark",
            background: String(Colours.palette.m3surface),
            surface: String(Colours.palette.m3surfaceContainer),
            surfaceVariant: String(Colours.palette.m3surfaceContainerHigh),
            foreground: String(Colours.palette.m3onSurface),
            muted: String(Colours.palette.m3onSurfaceVariant),
            accent: String(Colours.palette.m3primary),
            success: String(Colours.palette.m3tertiary),
            warning: String(Colours.palette.m3secondary),
            danger: String(Colours.palette.m3error),
            border: String(Colours.palette.m3outline),
            info: String(Colours.palette.m3primary)
        })
}
