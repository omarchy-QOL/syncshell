local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Validation = require("../models/FormModel.luau")
local Model = require("../models/PanelModel.luau")
local Dropdown = require("./SharedWidgetDropdown.luau")
local Form = {}

local function sourceSelector(controller, form)
    local rows = { { id = "", label = "Enter device ID", description = "Copy the ID from the remote Syncthing device" } }
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
    return ui.column({ gap = 6 }, {
        Dropdown.render(controller, form, "device-source", "Device source", rows, form.sourceId or "", function(id)
            local source = sources[id]
            form.sourceId, form.deviceId, form.name, form.address = id, id, source.name or "", source.address or ""
            form.sourceRevision = (form.sourceRevision or 0) + 1
        end),
        SharedWidgetControls.label(#rows == 1 and "No nearby or pending device found. Enter a device ID." or "Choose a discovered device or enter its ID.", "on_surface_variant"),
    })
end

function Form.render(controller, form)
    local problem = Validation.problem(controller.snapshot, form)
    local children = { SharedWidgetControls.formHeader(controller, form.kind == "acceptDevice" and "Accept device" or "Add device") }
    if form.kind == "addDevice" then table.insert(children, sourceSelector(controller, form)) end
    table.insert(children, SharedWidgetControls.field(controller, form, "deviceId", "Device ID", {
        focus = true, enabled = form.kind ~= "acceptDevice" and (not form.sourceId or form.sourceId == ""),
        revision = form.sourceRevision, placeholder = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-..." }))
    table.insert(children, SharedWidgetControls.button("Copy device ID", function() controller:copy(form.deviceId) end, form.deviceId ~= ""))
    table.insert(children, SharedWidgetControls.field(controller, form, "name", "Name (optional)", {
        revision = form.sourceRevision, focus = form.kind == "acceptDevice",
        placeholder = "Adopted from the remote device when empty", onSubmit = function() controller:submitForm() end }))
    table.insert(children, SharedWidgetControls.label("Observed address: " .. (form.address ~= "" and form.address or "Not available"), "on_surface_variant"))
    table.insert(children, SharedWidgetControls.label("Syncthing discovers connection addresses automatically. Advanced address settings are available in the Web UI."))
    table.insert(children, SharedWidgetControls.label(problem or "Ready to add this device", problem and "error" or "on_surface_variant"))
    table.insert(children, SharedWidgetControls.button(controller:actionLabel("device.add", "Add device"), function() controller:submitForm() end,
        problem == nil and not controller:busy() and controller.status.ready, "primary", "submit-device"))
    return ui.column({ gap = 10 }, children)
end

return Form
