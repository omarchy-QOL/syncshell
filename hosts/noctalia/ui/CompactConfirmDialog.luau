local Actions = require("../models/ActionModel.luau")
local Controls = require("./Controls.luau")
local Confirm = {}

function Confirm.render(controller)
    local confirm = controller.view.confirm
    return ui.column({ key = "confirmation", gap = 12, padding = 12 }, {
        Controls.label(Actions.label(confirm.action)),
        ui.scroll({ flexGrow = 1 }, { Controls.label(confirm.message) }),
        ui.row({ gap = 8 }, {
            Controls.button("Cancel", function() controller:cancel() end, not controller:busy(), confirm.choice == "cancel" and "primary" or "default", "confirmation-cancel"),
            Controls.button(Actions.label(confirm.action), function() controller:acceptConfirmation() end, not controller:busy(), Actions.destructive(confirm.action) and "destructive" or (confirm.choice == "accept" and "primary" or "default"), "confirmation-accept"),
        }),
        Controls.button("Copy confirmation details", function() controller:copy(confirm.message) end),
        Controls.label("Shortcut choice: " .. (confirm.choice == "accept" and Actions.label(confirm.action) or "Cancel") .. " | Alt+Up/Down: choose | Alt+Enter: activate", "on_surface_variant"),
        Controls.label("Tab selects Cancel first; Enter or Space activates the focused button. Alt+Left cancels. Escape closes the panel.", "on_surface_variant"),
    })
end

return Confirm
