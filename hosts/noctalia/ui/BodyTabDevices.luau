local Model = require("../models/PanelModel.luau")
local BodyTabDevicesCard = require("./BodyTabDevicesCard.luau")
local Dropdown = require("./SharedWidgetDropdown.luau")
local ActionButton = require("./SharedWidgetSquareActionButton.luau")
local Devices = {}

function Devices.render(controller)
    local view = controller.view
    local devices, rows = Model.remoteDevices(controller.snapshot), {}
    local connection = controller.snapshot.connection or {}
    for _, device in devices do
        table.insert(rows, { id = device.id, label = device.name ~= "" and device.name or device.id,
            role = Model.deviceStateRole(device, connection.online and connection.fresh),
            description = ((not connection.online or not connection.fresh) and "Current status unavailable"
                or (device.paused and "Paused" or (device.connected and "Connected" or "Offline"))) .. " | " .. device.id })
    end
    local device = Model.find(devices, view.deviceId)
    local enabled = connection.online and connection.fresh and not controller:busy()
    local toolbar = {}
    if #devices > 0 then
        table.insert(toolbar, Dropdown.render(controller, view, "device", "Device", rows, view.deviceId,
            function(id) view.deviceId = id end, { detached = true, placeholder = "To search press '/'" }))
    else
        table.insert(toolbar, ui.label({ text = connection.online and "No remote devices configured."
            or "Device status is unavailable.", color = "on_surface_variant", flexGrow = 1 }))
    end
    table.insert(toolbar, ActionButton.render("Add device", "plus", function()
        controller:openForm("addDevice")
    end, enabled))
    if #devices > 0 then
        table.insert(toolbar, ActionButton.render("Shared folders", "folders", function()
            controller:openForm("deviceFolders", device)
        end, enabled and device ~= nil, nil, "View folder shared\nwith selected device"))
        table.insert(toolbar, ActionButton.render("Remove", "x", function()
            controller:confirm("Remove " .. (device.name ~= "" and device.name or device.id) .. " from this device?\n\n"
                .. "Folder sharing with it will be removed locally. Local folders and files remain.\nThe other device is unchanged.",
                "device.remove", { deviceId = device.id })
        end, enabled and device ~= nil, "destructive", "Remove selected device"))
    end
    local children = { ui.row({ key = "device-toolbar", gap = 6, align = "center" }, toolbar) }
    if controller.dropdownList then table.insert(children, controller.dropdownList)
    elseif device then table.insert(children, BodyTabDevicesCard.render(controller, device)) end
    return ui.column({ key = "devices", gap = 8 }, children)
end

return Devices
