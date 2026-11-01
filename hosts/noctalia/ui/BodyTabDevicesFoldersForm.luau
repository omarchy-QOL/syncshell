local SharedWidgetControls = require("./SharedWidgetControls.luau")
local BodyFormHeader = require("./BodyFormHeader.luau")
local Model = require("../models/PanelModel.luau")
local Validation = require("../models/FormModel.luau")
local MultiSelect = require("./SharedWidgetMultiSelect.luau")
local Form = {}

function Form.render(controller, form)
    local device = Model.find(controller.snapshot.devices, form.deviceId)
    local groups = Model.deviceShares(controller.snapshot, form.deviceId)
    local children = {
        BodyFormHeader.render(controller, "SHARED WITH " .. (device and (device.name ~= "" and device.name or device.id) or "DEVICE")),
    }
    if not device then table.insert(children, SharedWidgetControls.hint("Device is no longer configured", "error")) end
    if #groups.confirmed + #groups.unconfirmed == 0 then
        table.insert(children, SharedWidgetControls.hint("No folders are currently shared with this device.", "secondary"))
    end
    table.insert(children, MultiSelect.render(controller, form, groups.confirmed, "Confirmed remote sharing, including remote-paused folders.",
        { key = "confirmed", label = "Existing shares", group = true, empty = "No confirmed shares", placeholder = "Find a folder..." }))
    table.insert(children, MultiSelect.render(controller, form, groups.unconfirmed, "A configured share is not proof of remote acceptance.",
        { key = "unconfirmed", label = "Unconfirmed shares", note = "(acceptance pending/device offline)", group = true,
            empty = "No unconfirmed shares", placeholder = "Find a folder..." }))
    table.insert(children, SharedWidgetControls.hint("Use the share folder button to restore a folder.", "secondary"))
    table.insert(children, SharedWidgetControls.button(controller:actionLabel("device.remove-folder-shares", "SAVE SHARING"), function() controller:submitForm() end,
        Validation.problem(controller.snapshot, form) == nil and not controller:busy()
            and controller.status.ready, "outline", "save-device-folders"))
    return ui.column({ gap = 8 }, children)
end

return Form
