local SquareActionButton = {}

function SquareActionButton.render(label, glyph, callback, enabled, variant, help, size)
    return ui.button({ key = label, text = "", glyph = glyph, tooltip = help or label,
        width = size or 32, height = size or 32, glyphSize = size and 14 or 16,
        controlSize = "sm", variant = variant or "outline", enabled = enabled ~= false,
        onClick = callback })
end

return SquareActionButton
