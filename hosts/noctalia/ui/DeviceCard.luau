local Controls = require("./Controls.luau")
local Model = require("../models/PanelModel.luau")
local Card = {}

function Card.render(controller, device)
    if not device then return Controls.label("Select a device. The previous selection may no longer exist.") end
    local connection = controller.snapshot.connection or {}
    local fresh = connection.online and connection.fresh
    local enabled = fresh and not controller:busy()
    local state = device.paused and "PAUSED" or (device.connected and "CONNECTED" or "DISCONNECTED")
    return ui.column({ key = "device-" .. device.id, gap = 8, padding = 10, fill = "surface_variant" }, {
        Controls.label(device.name ~= "" and device.name or device.id),
        Controls.label(fresh and state or ("UNKNOWN | Last reported: " .. state), fresh and device.connected and "tertiary" or "on_surface_variant"),
        Controls.label(device.id), Controls.label("Address: " .. (device.address or "Unavailable")),
        Controls.label("Download " .. Model.bytes(device.downloadBps) .. "/s | Upload " .. Model.bytes(device.uploadBps) .. "/s"),
        ui.row({ gap = 6 }, {
            Controls.button("Copy ID", function() controller:copy(device.id) end),
            Controls.button("Shared folders", function() controller:openForm("deviceFolders", device) end, enabled),
        }),
        ui.row({ gap = 6 }, {
            Controls.button(device.paused and "Resume" or "Pause", function()
                controller:send(device.paused and "device.resume" or "device.pause", { deviceId = device.id })
            end, enabled, nil, controller:actionKey("device-pause-" .. device.id)),
            Controls.button("Edit in Web UI", function() controller:send("webui.open", { deviceId = device.id }) end, enabled),
            Controls.button("Remove", function()
                controller:confirm("Remove " .. device.name .. " (" .. device.id .. ")? Its local folder shares are removed; files and the remote device remain unchanged.",
                    "device.remove", { deviceId = device.id })
            end, enabled, "destructive"),
        }),
    })
end

return Card
