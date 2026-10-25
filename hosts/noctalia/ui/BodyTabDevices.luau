local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Model = require("../models/PanelModel.luau")
local BodyTabDevicesCard = require("./BodyTabDevicesCard.luau")
local Dropdown = require("./SharedWidgetDropdown.luau")
local Devices = {}

function Devices.render(controller)
    local view = controller.view
    local devices, rows = Model.remoteDevices(controller.snapshot), {}
    local connection = controller.snapshot.connection or {}
    for _, device in devices do
        table.insert(rows, { id = device.id, label = device.name ~= "" and device.name or device.id,
            description = ((not connection.online or not connection.fresh) and "Current status unavailable"
                or (device.paused and "Paused" or (device.connected and "Connected" or "Offline"))) .. " | " .. device.id })
    end
    return ui.column({ gap = 8 }, {
        SharedWidgetControls.button("Add device", function() controller:openForm("addDevice") end, not controller:busy()),
        Dropdown.render(controller, view, "device", "Device", rows, view.deviceId, function(id) view.deviceId = id end),
        BodyTabDevicesCard.render(controller, Model.find(devices, view.deviceId)),
    })
end

return Devices
