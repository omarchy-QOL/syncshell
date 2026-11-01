local InfoPair = {}

function InfoPair.render(label, value)
    return ui.row({ gap = 8, align = "center" }, {
        ui.label({ text = label, color = "on_surface_variant", fontSize = 12, flexGrow = 1 }),
        ui.label({ text = tostring(value), color = "on_surface", fontSize = 12, textAlign = "end" }),
    })
end

return InfoPair
