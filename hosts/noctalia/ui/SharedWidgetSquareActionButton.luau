local SquareActionButton = {}

function SquareActionButton.render(label, glyph, callback, enabled, variant, help, size, tint)
    local side = size or 32
    if tint then
        -- Native buttons fix their glyph color; Omarchy tints these outlined icons.
        enabled = enabled ~= false
        return ui.row({ key = label, width = side, height = side, align = "center", justify = "center", radius = 6,
            border = "outline", borderWidth = 1, tooltip = help or label, opacity = enabled and 1 or 0.5,
            onClick = enabled and callback or nil }, { ui.glyph({ name = glyph, size = size and 14 or 16, color = tint }) })
    end
    return ui.button({ key = label, text = "", glyph = glyph, tooltip = help or label,
        width = side, height = side, glyphSize = size and 14 or 16,
        controlSize = "sm", variant = variant or "outline", enabled = enabled ~= false,
        onClick = callback })
end

return SquareActionButton
