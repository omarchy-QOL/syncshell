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
    -- As Omarchy: the frame and a chosen plain answer use the accent; only a
    -- destructive confirmation is red.
    local function answer(key, text, chosen, callback, destructive)
        local enabled = not controller:busy()
        local border, fill, color
        if destructive then
            border, fill, color = chosen and "error" or "error/0.56", chosen and "error/0.22" or "#00000000", chosen and "error" or "on_surface"
        else
            border, fill, color = chosen and "primary" or "on_surface/0.38", chosen and "on_surface/0.08" or "#00000000", chosen and "primary" or "on_surface"
        end
        return ui.row({ key = key, height = Ui.control, flexGrow = 1, align = "center", justify = "center", radius = 3, borderWidth = 1,
            border = border, fill = fill, opacity = enabled and 1 or 0.5, onClick = enabled and callback or nil },
            { ui.label({ text = text, color = color, fontSize = Ui.caption, maxLines = 1 }) })
    end
    return ui.column({ key = "confirmation", gap = 12, padding = 12, radius = 4, border = "primary", borderWidth = 1 }, {
        ui.label({ text = confirm.message, fontSize = Ui.body, maxLines = 0 }),
        ui.row({ gap = 8 }, {
            answer("confirmation-accept", create and "Create and add" or "Yes", confirm.choice == "accept", function() controller:acceptConfirmation() end, not create),
            answer("confirmation-cancel", create and "Cancel" or "No", confirm.choice ~= "accept", function() controller:cancel() end),
        }),
    })
end

Confirm.label = Actions.label

return Confirm
