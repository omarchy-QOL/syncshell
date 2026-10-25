local Actions = require("../models/ActionModel.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Confirm = {}

function Confirm.render(controller)
    local confirm = controller.view.confirm
    return ui.column({ key = "confirmation", gap = 12, padding = 12 }, {
        SharedWidgetControls.label(Actions.label(confirm.action)),
        ui.scroll({ flexGrow = 1 }, { SharedWidgetControls.label(confirm.message) }),
        ui.row({ gap = 8 }, {
            SharedWidgetControls.button("Cancel", function() controller:cancel() end, not controller:busy(), confirm.choice == "cancel" and "primary" or "default", "confirmation-cancel"),
            SharedWidgetControls.button(Actions.label(confirm.action), function() controller:acceptConfirmation() end, not controller:busy(), Actions.destructive(confirm.action) and "destructive" or (confirm.choice == "accept" and "primary" or "default"), "confirmation-accept"),
        }),
        SharedWidgetControls.button("Copy confirmation details", function() controller:copy(confirm.message) end),
        SharedWidgetControls.label("Shortcut choice: " .. (confirm.choice == "accept" and Actions.label(confirm.action) or "Cancel") .. " | Alt+Up/Down: choose | Alt+Enter: activate", "on_surface_variant"),
        SharedWidgetControls.label("Tab selects Cancel first; Enter or Space activates the focused button. Alt+Left cancels. Escape closes the panel.", "on_surface_variant"),
    })
end

return Confirm
