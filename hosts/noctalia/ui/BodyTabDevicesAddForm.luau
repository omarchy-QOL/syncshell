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

local function acceptForm(controller, form, problem)
    local children = {
        BodyFormHeader.render(controller, "ACCEPT REMOTE DEVICE REQUEST"),
        SharedWidgetControls.field(controller, form, "name", "Name", { focus = true, revision = form.sourceRevision,
            placeholder = "Optional name", onSubmit = function() controller:submitForm() end }),
    }
    if form.address and form.address ~= "" then
        table.insert(children, ui.column({ gap = 2 }, { SharedWidgetControls.caption("Observed address"), SharedWidgetControls.hint(form.address) }))
    end
    table.insert(children, ui.column({ gap = 4 }, {
        SharedWidgetControls.caption("Device ID"),
        ui.row({ gap = 6, align = "center" }, {
            ui.label({ text = form.deviceId, fontSize = Ui.caption, maxLines = 3, flexGrow = 1 }),
            IdCopyButton.render(controller, form.deviceId, "Copy device ID", "Copy device ID"),
        }),
    }))
    if problem then table.insert(children, SharedWidgetControls.hint(problem, "error")) end
    table.insert(children, SharedWidgetControls.button(controller:actionLabel("device.add", "ACCEPT REMOTE DEVICE CONNECTION", "ACCEPTING..."),
        function() controller:submitForm() end, problem == nil and not controller:busy() and controller.status.ready, "outline", "submit-device"))
    return ui.column({ gap = 8 }, children)
end

function Form.render(controller, form)
    local problem = Validation.problem(controller.snapshot, form)
    if form.kind == "acceptDevice" then return acceptForm(controller, form, problem) end
    local children = { BodyFormHeader.render(controller, "ADD REMOTE DEVICE"), sourceSelector(controller, form) }
    table.insert(children, SharedWidgetControls.field(controller, form, "deviceId", "Device ID", {
        focus = true, enabled = not form.sourceId or form.sourceId == "",
        revision = form.sourceRevision, placeholder = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-..." }))
    if form.nearbyEmpty then
        table.insert(children, SharedWidgetControls.hint("No nearby device found. Use the device ID.", Palette.roles.warning))
    end
    table.insert(children, SharedWidgetControls.field(controller, form, "name", "Remote Device Name", {
        revision = form.sourceRevision,
        placeholder = "Optional; adopted from the remote when empty", onSubmit = function() controller:submitForm() end }))
    if problem and form.deviceId ~= "" then table.insert(children, SharedWidgetControls.hint(problem, "error")) end
    table.insert(children, SharedWidgetControls.button(controller:actionLabel("device.add", "ADD REMOTE DEVICE", "ADDING..."), function() controller:submitForm() end,
        problem == nil and not controller:busy() and controller.status.ready, "outline", "submit-device"))
    return ui.column({ gap = 8 }, children)
end

return Form
