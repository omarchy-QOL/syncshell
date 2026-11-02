local Palette = require("../controllers/ThemePaletteController.luau")
local Ui = require("./UiConstants.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Validation = require("../models/FormModel.luau")
local Model = require("../models/PanelModel.luau")
local Dropdown = require("./SharedWidgetDropdown.luau")
local BodyFormHeader = require("./BodyFormHeader.luau")
local IdCopyButton = require("./SharedWidgetIdCopyButton.luau")
local Form = {}

local function sourceSelector(controller, form)
    local rows = { { id = "", label = "Custom Device ID" } }
    local sources = { [""] = { id = "", name = "", address = "" } }
    for _, device in controller.snapshot.nearbyDevices or {} do
        local addresses = device.addresses or {}
        sources[device.id] = { id = device.id, name = "", address = addresses[1] or "" }
        table.insert(rows, { id = device.id, label = Model.shortDeviceId(device.id) .. (addresses[1] and (" · " .. addresses[1]) or "") })
    end
    form.nearbyEmpty = #rows == 1
    return ui.column({ gap = 4 }, {
        SharedWidgetControls.caption("Device source"),
        Dropdown.render(controller, form, "device-source", "Device source", rows, form.sourceId or "", function(id)
            local source = sources[id]
            form.sourceId, form.deviceId, form.address = id, id, source.address or ""
            form.sourceRevision = (form.sourceRevision or 0) + 1
        end),
    })
end

local function inline(caption, value)
    return ui.row({ gap = 8, align = "center" }, { SharedWidgetControls.caption(caption), value })
end

-- Omarchy's accept form keeps each caption beside its value.
local function acceptForm(controller, form)
    local children = {
        BodyFormHeader.render(controller, "ACCEPT REMOTE DEVICE REQUEST"),
        inline("Name", ui.input({ key = "form-" .. tostring(form.token) .. "-name-" .. tostring(form.sourceRevision or 0), value = form.name or "",
            placeholder = "Optional name", focus = true, height = Ui.control, fontSize = Ui.body, flexGrow = 1, enabled = not controller:busy(),
            onChange = function(value) form.name = value; controller:save() end })),
    }
    if form.address and form.address ~= "" then
        table.insert(children, inline("Observed address", ui.label({ text = form.address, color = "on_surface_variant", fontSize = Ui.caption, maxLines = 1, flexGrow = 1, textAlign = "end" })))
    end
    table.insert(children, inline("Device ID", ui.row({ gap = 6, align = "center", flexGrow = 1 }, {
        ui.label({ text = form.deviceId, fontSize = Ui.caption, maxLines = 1, flexGrow = 1, textAlign = "end" }),
        IdCopyButton.render(controller, form.deviceId, "Copy device ID", "Copy device ID", "Device ID copied"),
    })))
    table.insert(children, SharedWidgetControls.button(controller:actionLabel("device.add", "ACCEPT REMOTE DEVICE CONNECTION", "ACCEPTING..."),
        function() controller:submitForm() end, not controller:busy() and controller.status.ready, "outline", "submit-device"))
    return ui.column({ gap = 8 }, children)
end

function Form.render(controller, form)
    if form.kind == "acceptDevice" then return acceptForm(controller, form) end
    local children = { BodyFormHeader.render(controller, "ADD REMOTE DEVICE"), sourceSelector(controller, form) }
    table.insert(children, SharedWidgetControls.field(controller, form, "deviceId", "Device ID", {
        focus = true, enabled = not form.sourceId or form.sourceId == "",
        revision = form.sourceRevision, placeholder = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-..." }))
    if form.nearbyEmpty then
        table.insert(children, ui.row({ gap = 4, align = "center" }, {
            ui.glyph({ name = "alert-triangle", size = Ui.caption, color = Palette.roles.warning }),
            SharedWidgetControls.hint("No nearby device found. Use the device ID.", Palette.roles.warning),
        }))
    end
    table.insert(children, SharedWidgetControls.field(controller, form, "name", "Remote Device Name", {
        revision = form.sourceRevision,
        placeholder = "Optional; adopted from the remote when empty" }))
    table.insert(children, SharedWidgetControls.button(controller:actionLabel("device.add", "ADD REMOTE DEVICE", "ADDING..."), function() controller:submitForm() end,
        Model.validDeviceId(Validation.deviceId(form.deviceId)) and not controller:busy() and controller.status.ready, "outline", "submit-device"))
    return ui.column({ gap = 8 }, children)
end

return Form
