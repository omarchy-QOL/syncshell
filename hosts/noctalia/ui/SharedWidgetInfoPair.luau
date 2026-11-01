local Ui = require("./UiConstants.luau")
local InfoPair = {}

function InfoPair.render(label, value)
    return ui.row({ gap = 8, align = "center" }, {
        ui.label({ text = label, color = "on_surface_variant", fontSize = Ui.bodySmall, flexGrow = 1 }),
        ui.label({ text = tostring(value), color = "on_surface", fontSize = Ui.bodySmall, textAlign = "end" }),
    })
end

return InfoPair
