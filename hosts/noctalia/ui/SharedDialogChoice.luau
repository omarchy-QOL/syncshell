local Ui = require("./UiConstants.luau")
local Choice = {}

-- Omarchy's forced choice when the saved preference and systemd disagree.
function Choice.render(controller, decision)
    local function option(key, item)
        return ui.button({ key = key, text = item.label, height = Ui.control, fontSize = Ui.body, contentAlign = "start",
            variant = controller.view.driftChoice == key and "default" or "outline", enabled = not controller:busy(),
            onClick = function() controller:chooseDrift(item) end })
    end
    return ui.column({ key = "service-state-choice", gap = 8, padding = 12, radius = 4, border = "outline", borderWidth = 1 }, {
        ui.label({ text = decision.message, fontSize = Ui.body, maxLines = 0 }),
        option("drift-first", decision.first),
        option("drift-second", decision.second),
    })
end

return Choice
