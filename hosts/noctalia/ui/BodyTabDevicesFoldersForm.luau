local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Model = require("../models/PanelModel.luau")
local Validation = require("../models/FormModel.luau")
local MultiSelect = require("./SharedWidgetMultiSelect.luau")
local Form = {}

function Form.render(controller, form)
    local device = Model.find(controller.snapshot.devices, form.deviceId)
    local groups = Model.deviceShares(controller.snapshot, form.deviceId)
    return ui.column({ gap = 10 }, {
        SharedWidgetControls.formHeader(controller, "Folders shared with this device"),
        SharedWidgetControls.label(device and ((device.name or device.id) .. " | " .. device.id) or "Device is no longer configured"),
        SharedWidgetControls.label(tostring(#groups.confirmed) .. " confirmed | " .. tostring(#groups.unconfirmed) .. " unconfirmed", "on_surface_variant"),
        MultiSelect.render(controller, form, groups.confirmed, "Confirmed remote sharing, including remote-paused folders.",
            { key = "confirmed", label = "Existing shares", group = true }),
        MultiSelect.render(controller, form, groups.unconfirmed, "Acceptance pending or current remote status unavailable. A configured share is not proof of remote acceptance.",
            { key = "unconfirmed", label = "Unconfirmed shares", group = true }),
        SharedWidgetControls.label("Uncheck shares to remove. Restore a share from the folder's Sharing form."),
        SharedWidgetControls.button(controller:actionLabel("device.remove-folder-shares", "Review removals"), function() controller:submitForm() end,
            Validation.problem(controller.snapshot, form) == nil and not controller:busy()
                and controller.status.ready, "primary", "save-device-folders"),
    })
end

return Form
