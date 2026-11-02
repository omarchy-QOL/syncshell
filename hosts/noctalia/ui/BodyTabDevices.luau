local Model = require("../models/PanelModel.luau")
local BodyTabDevicesCard = require("./BodyTabDevicesCard.luau")
local Dropdown = require("./SharedWidgetDropdown.luau")
local ActionButton = require("./SharedWidgetSquareActionButton.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Ui = require("./UiConstants.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local Devices = {}

function Devices.render(controller)
    local view = controller.view
    local devices, rows = Model.remoteDevices(controller.snapshot), {}
    local connection = controller.snapshot.connection or {}
    for _, device in devices do
        local state = device.paused and "PAUSED · Connections disabled" or (device.connected and "CONNECTED · Available" or "DISCONNECTED")
        table.insert(rows, { id = device.id, label = Model.deviceLabel(device), role = Model.deviceStateRole(device), description = state })
    end
    local device = Model.find(devices, view.deviceId)
    local busy = controller:busy()
    local online = connection.online == true
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
    end, online and not busy))
    if #devices > 0 then
        table.insert(toolbar, ActionButton.render("Shared folders", "folders", function()
            controller:openForm("deviceFolders", device)
        end, device ~= nil and not busy, nil, "View folder shared\nwith selected device"))
        table.insert(toolbar, ActionButton.render("Remove", "x", function()
            controller:confirm("Remove " .. Model.deviceLabel(device) .. " from this device?\n\n"
                .. "Folder sharing with it will be removed locally. Local folders and files remain.\nThe other device is unchanged.",
                "device.remove", { deviceId = device.id })
        end, device ~= nil and online and not busy, nil, "Remove selected device", nil, "error"))
    end
    local children = { ui.row({ key = "device-toolbar", gap = 6, align = "center" }, toolbar) }
    if controller.dropdownList then table.insert(children, controller.dropdownList)
    elseif device then
        table.insert(children, BodyTabDevicesCard.render(controller, device))
        local shared = false
        for _, folder in controller.snapshot.folders or {} do shared = shared or Model.shares(folder, device.id) end
        if not shared then
            table.insert(children, ui.row({ gap = 4, align = "center" }, {
                SharedWidgetControls.hint("No folders are shared. Use the", Palette.roles.warning),
                ui.glyph({ name = "share", size = Ui.caption, color = Palette.roles.warning }),
                SharedWidgetControls.hint("button to share a folder.", Palette.roles.warning),
            }))
        end
    end
    return ui.column({ key = "devices", gap = 8 }, children)
end

return Devices
