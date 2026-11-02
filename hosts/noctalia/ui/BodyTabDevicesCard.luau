local Ui = require("./UiConstants.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Model = require("../models/PanelModel.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local IdCopyButton = require("./SharedWidgetIdCopyButton.luau")
local Card = {}

local function detail(glyph, text)
    return ui.row({ gap = 6, align = "center" }, {
        ui.glyph({ name = glyph, size = Ui.caption, color = "on_surface_variant" }),
        ui.label({ text = text, color = "on_surface_variant", fontSize = Ui.caption, maxLines = 1 }),
    })
end

function Card.render(controller, device)
    if not device then return SharedWidgetControls.label("Select a device. The previous selection may no longer exist.") end
    local connection = controller.snapshot.connection or {}
    local online = connection.online == true
    local enabled = online and not controller:busy()
    local state = device.paused and "PAUSED" or (device.connected and "CONNECTED" or "DISCONNECTED")
    local shared = 0
    local total = #(controller.snapshot.folders or {})
    for _, folder in controller.snapshot.folders or {} do
        if Model.shares(folder, device.id) then shared += 1 end
    end
    local pending = device.paused and "device.resume" or "device.pause"
    return ui.column({ key = "device-" .. device.id, gap = 6, padding = 6, radius = 2, border = "outline", borderWidth = 1 }, {
        ui.row({ gap = 4, align = "center" }, {
            SharedWidgetControls.chip("edit-device-" .. device.id, "device-desktop", Model.deviceLabel(device), function()
                controller:openWebUi()
            end, online, "Open this device in the Web UI"),
            IdCopyButton.render(controller, device.id, "copy-device-" .. device.id, "Copy device ID", "Remote device ID copied"),
            ui.spacer({ flexGrow = 1 }),
            SharedWidgetControls.badge("device-state-" .. device.id, state,
                Palette.roles[Model.deviceStateRole(device)]),
        }),
        ui.row({ gap = 8, align = "end" }, {
            ui.column({ gap = 3, flexGrow = 1, minWidth = 0 }, {
                detail("folder", tostring(shared) .. "/" .. tostring(total) .. " folder" .. (total == 1 and "" or "s")
                    .. " shared"),
                ui.row({ gap = 10, align = "center" }, {
                    detail("download", Model.bytes(device.downloadBps) .. "/s"),
                    detail("upload", Model.bytes(device.uploadBps) .. "/s"),
                }),
                detail("sitemap", device.address or "Address unavailable"),
            }),
            ui.button({ key = "device-pause", text = controller:actionLabel(pending, device.paused and "RESUME" or "PAUSE", device.paused and "RESUMING" or "PAUSING"),
                glyph = device.paused and "player-play-filled" or "player-pause-filled", fontSize = Ui.body, glyphSize = Ui.body, height = Ui.cardControl,
                variant = "outline", enabled = enabled, tooltip = device.paused and "Resume synchronization with this device" or "Pause synchronization with this device",
                onClick = function() controller:send(pending, { deviceId = device.id }) end }),
        }),
    })
end

return Card
