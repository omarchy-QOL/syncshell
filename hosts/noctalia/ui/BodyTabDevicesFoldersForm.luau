local Palette = require("../controllers/ThemePaletteController.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local BodyFormHeader = require("./BodyFormHeader.luau")
local Model = require("../models/PanelModel.luau")
local Validation = require("../models/FormModel.luau")
local MultiSelect = require("./SharedWidgetMultiSelect.luau")
local Ui = require("./UiConstants.luau")
local Form = {}

function Form.render(controller, form)
    local device = Model.find(controller.snapshot.devices, form.deviceId)
    local groups = Model.deviceShares(controller.snapshot, form.deviceId)
    local children = {
        BodyFormHeader.render(controller, "SHARED WITH " .. (device and Model.deviceLabel(device) or "DEVICE")),
    }
    if not device then table.insert(children, SharedWidgetControls.hint("Device is no longer configured", "error")) end
    -- Omarchy shows only the message when nothing is shared.
    if #groups.confirmed + #groups.unconfirmed == 0 then
        table.insert(children, SharedWidgetControls.hint("No folders are currently shared with this device.", Palette.roles.warning))
        return ui.column({ gap = 8 }, children)
    end
    table.insert(children, MultiSelect.render(controller, form, groups.confirmed, nil,
        { key = "confirmed", label = "Existing shares", group = true, empty = "No confirmed shares", placeholder = "Find a folder..." }))
    table.insert(children, MultiSelect.render(controller, form, groups.unconfirmed, nil,
        { key = "unconfirmed", label = "Unconfirmed shares", note = #groups.unconfirmed > 0 and "(acceptance pending/device offline)" or nil, group = true,
            empty = "No unconfirmed shares", placeholder = "Find a folder..." }))
    table.insert(children, ui.row({ gap = 4, align = "center" }, {
        ui.glyph({ name = "alert-triangle", size = Ui.caption, color = Palette.roles.warning }),
        SharedWidgetControls.hint("Use", Palette.roles.warning),
        ui.glyph({ name = "share", size = Ui.caption, color = Palette.roles.warning }),
        SharedWidgetControls.hint("button (share folder) to restore a folder.", Palette.roles.warning),
    }))
    table.insert(children, SharedWidgetControls.button(controller:actionLabel("device.remove-folder-shares", "SAVE SHARING", "SAVING..."), function() controller:submitForm() end,
        Validation.problem(controller.snapshot, form) == nil and not controller:busy()
            and controller.status.ready, "outline", "save-device-folders"))
    return ui.column({ gap = 8 }, children)
end

return Form
