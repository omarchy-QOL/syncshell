local FooterShortcutHint = {}

function FooterShortcutHint.render()
    return ui.label({ text = "[r]escan  [w]ebUI  [p]ause/continue  [s]ettings", color = "on_surface_variant",
        fontSize = 11, textAlign = "center", maxLines = 1 })
end

return FooterShortcutHint
