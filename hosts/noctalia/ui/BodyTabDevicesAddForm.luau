local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Validation = require("../models/FormModel.luau")
local Model = require("../models/PanelModel.luau")
local Dropdown = require("./SharedWidgetDropdown.luau")
local BodyFormHeader = require("./BodyFormHeader.luau")
local Form = {}

local function sourceSelector(controller, form)
    local rows = { { id = "", label = "Custom Device ID", description = "Copy the ID from the remote Syncthing device" } }
    local sources = { [""] = { id = "", name = "", address = "" } }
    for _, device in controller.snapshot.pendingDevices or {} do
        if not Model.find(controller.snapshot.devices, device.id) then
            sources[device.id] = device
            table.insert(rows, { id = device.id, label = device.name ~= "" and device.name or "Pending device",
                description = "Invitation | " .. device.id .. " | " .. (device.address or "No observed address") })
        end
    end
    for _, device in controller.snapshot.nearbyDevices or {} do
        if not sources[device.id] and not Model.find(controller.snapshot.devices, device.id)
            and device.id ~= (controller.snapshot.identity or {}).deviceId then
            sources[device.id] = { id = device.id, name = "", address = table.concat(device.addresses or {}, ", ") }
            table.insert(rows, { id = device.id, label = "Nearby device", description = device.id .. " | " .. sources[device.id].address })
        end
    end
    form.nearbyEmpty = #rows == 1
    return ui.column({ gap = 4 }, {
        SharedWidgetControls.caption("Device source"),
        Dropdown.render(controller, form, "device-source", "Device source", rows, form.sourceId or "", function(id)
            local source = sources[id]
            form.sourceId, form.deviceId, form.name, form.address = id, id, source.name or "", source.address or ""
            form.sourceRevision = (form.sourceRevision or 0) + 1
        end),
    })
end

function Form.render(controller, form)
    local problem = Validation.problem(controller.snapshot, form)
    local accept = form.kind == "acceptDevice"
    local children = { BodyFormHeader.render(controller, accept and "ACCEPT REMOTE DEVICE" or "ADD REMOTE DEVICE") }
    if not accept then table.insert(children, sourceSelector(controller, form)) end
    table.insert(children, SharedWidgetControls.field(controller, form, "deviceId", "Device ID", {
        focus = true, enabled = not accept and (not form.sourceId or form.sourceId == ""),
        revision = form.sourceRevision, placeholder = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-..." }))
    if form.nearbyEmpty and not accept then
        table.insert(children, SharedWidgetControls.hint("No nearby device found. Use the device ID.", "secondary"))
    end
    table.insert(children, SharedWidgetControls.field(controller, form, "name", "Remote Device Name", {
        revision = form.sourceRevision, focus = accept,
        placeholder = "Optional; adopted from the remote when empty", onSubmit = function() controller:submitForm() end }))
    if form.address and form.address ~= "" then
        table.insert(children, SharedWidgetControls.hint("Observed address: " .. form.address))
    end
    if accept then
        table.insert(children, SharedWidgetControls.button("Copy device ID", function() controller:copy(form.deviceId) end, form.deviceId ~= ""))
    end
    if problem and form.deviceId ~= "" then table.insert(children, SharedWidgetControls.hint(problem, "error")) end
    table.insert(children, SharedWidgetControls.button(controller:actionLabel("device.add", accept and "ACCEPT REMOTE DEVICE" or "ADD REMOTE DEVICE"), function() controller:submitForm() end,
        problem == nil and not controller:busy() and controller.status.ready, "outline", "submit-device"))
    return ui.column({ gap = 8 }, children)
end

return Form
