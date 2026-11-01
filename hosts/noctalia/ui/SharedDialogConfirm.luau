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
    local accept, cancel = confirm.choice == "accept", confirm.choice ~= "accept"
    local border = create and "outline" or "error"
    return ui.column({ key = "confirmation", gap = 12, padding = 12, radius = 6, border = border, borderWidth = 1 }, {
        ui.label({ text = confirm.message, fontSize = 13, maxLines = 0 }),
        ui.row({ gap = 8 }, {
            ui.button({ key = "confirmation-accept", text = create and "Create and add" or "Yes", controlSize = "sm", flexGrow = 1,
                variant = accept and (create and "primary" or "destructive") or "outline", enabled = not controller:busy(),
                onClick = function() controller:acceptConfirmation() end }),
            ui.button({ key = "confirmation-cancel", text = create and "Cancel" or "No", controlSize = "sm", flexGrow = 1,
                variant = cancel and (create and "primary" or "destructive") or "outline", enabled = not controller:busy(),
                onClick = function() controller:cancel() end }),
        }),
    })
end

Confirm.label = Actions.label

return Confirm
