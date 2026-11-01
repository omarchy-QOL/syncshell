local Ui = require("./UiConstants.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local BodyFormHeader = {}

function BodyFormHeader.render(controller, title)
    local form = controller.view.form
    local nested = form and (form.returnForm or form.page)
    return ui.row({ gap = 8, align = "center" }, {
        ui.label({ text = title, color = "on_surface_variant", fontSize = Ui.caption, fontWeight = "bold", maxLines = 1, flexGrow = 1 }),
        SharedWidgetControls.tinted(nested and "Back" or "Cancel", nested and "BACK" or "CANCEL", nil, "error",
            function() controller:cancel() end, not controller:busy()),
    })
end

return BodyFormHeader
