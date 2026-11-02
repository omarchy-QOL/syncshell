local Ui = require("./UiConstants.luau")
local SquareActionButton = {}

function SquareActionButton.render(label, glyph, callback, enabled, variant, help, size, tint)
    local side = size or Ui.control
    if tint then
        -- Native buttons fix their glyph color; Omarchy tints these outlined icons.
        enabled = enabled ~= false
        return ui.row({ key = label, width = side, height = side, align = "center", justify = "center", radius = 6,
            border = "outline", borderWidth = 1, tooltip = help or label,
            onClick = enabled and callback or nil },
            -- As Omarchy: a disabled red action goes neutral, a green one stays green.
            { ui.glyph({ name = glyph, size = Ui.title, color = (not enabled and tint == "error") and "on_surface_variant" or tint }) })
    end
    return ui.button({ key = label, text = "", glyph = glyph, tooltip = help or label,
        width = side, height = side, glyphSize = size and Ui.body or Ui.title,
        controlSize = "sm", variant = variant or "outline", enabled = enabled ~= false,
        onClick = callback })
end

return SquareActionButton
