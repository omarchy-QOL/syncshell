local SharedWidgetControls = require("./SharedWidgetControls.luau")
local InfoPair = require("./SharedWidgetInfoPair.luau")
local Model = require("../models/PanelModel.luau")
local Header = {}

function Header.render(controller, compact)
    local s = controller.snapshot
    local identity, lifecycle, counts = s.identity or {}, s.lifecycle or {}, s.counts or {}
    local localDevice = Model.find(s.devices, identity.deviceId)
    local hostname = localDevice and localDevice.name or "This device"
    local connection = s.connection or {}
    local total = Model.totals(s)
    local variant = Model.indicator(s, controller.status)
    local prefix = controller.host.getConfig("brandedIcon") and "/assets/" or "/assets/mono/"
    local canToggle = lifecycle.canControl == true or (not lifecycle.active and lifecycle.canStart == true)
    local title = {
        ui.image({ path = controller.host.pluginDir() .. prefix .. "status-" .. variant .. ".svg", width = 32, height = 32 }),
        ui.column({ gap = 2, flexGrow = 1, minWidth = 0 }, {
            ui.label({ text = "Syncthing", fontSize = 15, fontWeight = "bold", maxLines = 1 }),
            ui.row({ gap = 6, align = "center" }, {
                ui.label({ text = string.upper(hostname), color = "on_surface_variant", fontSize = 11, maxLines = 1 }),
                ui.button({ key = "Copy ID", text = "device ID", glyph = "copy", fontSize = 10, glyphSize = 11, height = 18,
                    controlSize = "sm", variant = "outline", tooltip = "Copy device ID", enabled = identity.deviceId ~= nil,
                    onClick = function() controller:copy(identity.deviceId or "") end }),
            }),
        }),
    }
    -- Omarchy hides the switch when the instance is not ours to control.
    if canToggle then
        table.insert(title, ui.toggle({ checked = lifecycle.active == true, enabled = not controller:busy(),
            onChange = function(value)
                local enable = Model.bool(value)
                controller:confirm(enable and "Start the authorized Syncthing service?" or "Stop the authorized Syncthing service?",
                    enable and "lifecycle.start" or "lifecycle.stop", {})
            end }))
    end
    local children = {
        ui.row({ gap = 10, align = "center" }, title),
    }
    if not compact then
        table.insert(children, InfoPair.render("Folders", counts.folders or 0))
        table.insert(children, InfoPair.render("Devices", tostring(counts.connectedDevices or 0)
            .. " of " .. tostring(counts.devices or 0) .. " connected"))
        table.insert(children, InfoPair.render("Tracked", Model.count(total.files) .. " files · " .. Model.bytes(total.bytes)))
    end
    if controller.status.backgroundError then
        table.insert(children, SharedWidgetControls.notice(controller, controller.status.backgroundError
            .. "\nCheck plugin settings and the selected Web UI profile.", "error", "background action details"))
    end
    if connection.error then
        table.insert(children, SharedWidgetControls.notice(controller, connection.error.message .. "\nCheck connection and credential settings, then Refresh.", "error", "connection details"))
    elseif not connection.fresh then
        table.insert(children, SharedWidgetControls.notice(controller, "Current status unavailable; last reported values shown", "error", "status details"))
    end
    if lifecycle.error then
        table.insert(children, SharedWidgetControls.notice(controller, lifecycle.error, "on_surface_variant", "service details"))
    end
    return ui.column({ gap = 4 }, children)
end

return Header
