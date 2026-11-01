local SquareActionButton = {}

function SquareActionButton.render(label, glyph, callback, enabled, variant, help)
    return ui.button({ key = label, text = "", glyph = glyph, tooltip = help or label,
        controlSize = "sm", variant = variant or "outline", enabled = enabled ~= false,
        onClick = callback })
end

return SquareActionButton
