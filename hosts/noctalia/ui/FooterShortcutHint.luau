local Ui = require("./UiConstants.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local FooterShortcutHint = {}

local function text(value, color)
    return ui.label({ text = value, color = color, fontSize = Ui.caption, maxLines = 1 })
end

local function shortcut(key, rest)
    return ui.row({ gap = 0, align = "center" }, { text("[" .. key .. "]", Palette.roles.warning), text(rest, "on_surface_variant") })
end

function FooterShortcutHint.render()
    return ui.row({ key = "shortcut-hint", gap = 8, align = "center", justify = "center" }, {
        shortcut("r", "escan"), shortcut("w", "ebUI"), shortcut("p", "ause/continue"), shortcut("s", "ettings"),
    })
end

return FooterShortcutHint
