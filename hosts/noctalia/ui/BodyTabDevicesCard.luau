local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Model = require("../models/PanelModel.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local IdCopyButton = require("./SharedWidgetIdCopyButton.luau")
local Card = {}

function Card.render(controller, device)
    if not device then return SharedWidgetControls.label("Select a device. The previous selection may no longer exist.") end
    local connection = controller.snapshot.connection or {}
    local fresh = connection.online and connection.fresh
    local enabled = fresh and not controller:busy()
    local state = device.paused and "PAUSED" or (device.connected and "CONNECTED" or "DISCONNECTED")
    local edit = SharedWidgetControls.button(device.name ~= "" and device.name or device.id, function()
        controller:send("webui.open", { deviceId = device.id })
    end, enabled, "outline", "edit-device-" .. device.id, "Open this device in the Web UI")
    edit.props.flexGrow = 1
    local shared = 0
    for _, folder in controller.snapshot.folders or {} do
        if Model.shares(folder, device.id) then shared += 1 end
    end
    return ui.column({ key = "device-" .. device.id, gap = 8, padding = 10, fill = "surface_variant" }, {
        ui.row({ gap = 6, align = "center" }, {
            edit,
            IdCopyButton.render(controller, device.id, "copy-device-" .. device.id, "Copy device ID"),
            ui.label({ key = "device-state-" .. device.id, text = fresh and state or "UNKNOWN",
                color = Palette.roles[Model.deviceStateRole(device, fresh)], fontWeight = "bold" }),
        }),
        SharedWidgetControls.label(fresh and (device.paused and "Connections disabled"
            or (device.connected and "Available" or "Disconnected")) or ("Last reported: " .. state), "on_surface_variant"),
        SharedWidgetControls.label(tostring(shared) .. "/" .. tostring(#(controller.snapshot.folders or {}))
            .. " folders shared" .. (fresh and "" or " (last reported)"), "on_surface_variant"),
        SharedWidgetControls.label("Download " .. Model.bytes(device.downloadBps) .. "/s | Upload " .. Model.bytes(device.uploadBps) .. "/s"),
        SharedWidgetControls.label("Address: " .. (device.address or "Unavailable"), "on_surface_variant"),
        ui.row({ gap = 6 }, {
            SharedWidgetControls.button(controller:actionLabel(device.paused and "device.resume" or "device.pause",
                device.paused and "Resume" or "Pause"), function()
                controller:send(device.paused and "device.resume" or "device.pause", { deviceId = device.id })
            end, enabled, nil, controller:actionKey("device-pause-" .. device.id)),
        }),
    })
end

return Card
