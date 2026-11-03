local Ui = require("./UiConstants.luau")
local SquareActionButton = {}

function SquareActionButton.render(label, glyph, callback, enabled, variant, help, size, tint, disabledTint)
    local side = size or Ui.control
    if tint then
        -- Native buttons fix their glyph color; Omarchy tints these outlined icons.
        enabled = enabled ~= false
        return ui.row({ key = label, width = side, height = side, align = "center", justify = "center", radius = 6,
            border = enabled and "outline" or "outline/0.5", borderWidth = 1, tooltip = help or label,
            onClick = enabled and callback or nil },
            -- Omarchy darkens a disabled tint by 1.6 unless the button names its own color.
            { type(glyph) == "table" and glyph or ui.glyph({ name = glyph, size = Ui.title, color = enabled and tint or disabledTint or (tint .. "/0.62") }) })
    end
    return ui.button({ key = label, text = "", glyph = glyph, tooltip = help or label,
        width = side, height = side, glyphSize = size == Ui.smallControl and Ui.caption or (size and Ui.body or Ui.title),
        controlSize = "sm", variant = variant or "outline", enabled = enabled ~= false,
        onClick = callback })
end

return SquareActionButton
