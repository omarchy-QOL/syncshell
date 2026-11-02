local Ui = require("./UiConstants.luau")
local Actions = require("../models/ActionModel.luau")
local Confirm = {}

-- No overlay exists in this host: the body gives way to the dialog while the
-- rest of the panel is dimmed and inert, as in Omarchy's modal.
function Confirm.dim(node)
    if node.type == "button" or node.type == "toggle" or node.type == "input" then node.props.enabled = false end
    node.props.onClick = nil
    for _, child in node.children do Confirm.dim(child) end
    return node
end

function Confirm.render(controller)
    local confirm = controller.view.confirm
    local create = confirm.action == "folder.add-existing"
    local border = create and "outline" or "error"
    -- Omarchy tints the chosen answer rather than filling it.
    local function answer(key, text, chosen, callback)
        local enabled = not controller:busy()
        local color = chosen and border ~= "outline" and "error" or "on_surface"
        return ui.row({ key = key, height = Ui.control, flexGrow = 1, align = "center", justify = "center", radius = 3, borderWidth = 1,
            border = chosen and border or "outline", fill = chosen and (create and "surface_variant" or "error/0.15") or "#00000000",
            opacity = enabled and 1 or 0.5, onClick = enabled and callback or nil },
            { ui.label({ text = text, color = color, fontSize = Ui.body, maxLines = 1 }) })
    end
    return ui.column({ key = "confirmation", gap = 12, padding = 12, radius = 4, border = border, borderWidth = 1 }, {
        ui.label({ text = confirm.message, fontSize = Ui.body, maxLines = 0 }),
        ui.row({ gap = 8 }, {
            answer("confirmation-accept", create and "Create and add" or "Yes", confirm.choice == "accept", function() controller:acceptConfirmation() end),
            answer("confirmation-cancel", create and "Cancel" or "No", confirm.choice ~= "accept", function() controller:cancel() end),
        }),
    })
end

Confirm.label = Actions.label

return Confirm
