local InfoPair = {}

function InfoPair.render(label, value)
    return ui.row({ gap = 8, align = "center" }, {
        ui.label({ text = label, color = "on_surface_variant", flexGrow = 1 }),
        ui.label({ text = tostring(value), color = "on_surface", textAlign = "end" }),
    })
end

return InfoPair
