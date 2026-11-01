local SharedWidgetControls = require("./SharedWidgetControls.luau")
local BodyFormHeader = {}

function BodyFormHeader.render(controller, title)
    local nested = controller.view.form and controller.view.form.returnForm
    return ui.row({ gap = 8, align = "center" }, {
        ui.label({ text = title, color = "on_surface_variant", fontSize = 12, fontWeight = "bold", maxLines = 1, flexGrow = 1 }),
        ui.button({ key = nested and "Back" or "Cancel", text = nested and "BACK" or "CANCEL", controlSize = "sm", variant = "outline",
            fontSize = 11, height = 26, enabled = not controller:busy(), onClick = function() controller:cancel() end }),
    })
end

return BodyFormHeader
