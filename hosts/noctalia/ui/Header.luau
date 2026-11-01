local SharedWidgetControls = require("./SharedWidgetControls.luau")
local InfoPair = require("./SharedWidgetInfoPair.luau")
local Model = require("../models/PanelModel.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local Header = {}

function Header.render(controller)
    local s = controller.snapshot
    local identity, lifecycle, counts = s.identity or {}, s.lifecycle or {}, s.counts or {}
    local localDevice = Model.find(s.devices, identity.deviceId)
    local hostname = localDevice and localDevice.name or "This device"
    local connection = s.connection or {}
    local reason = lifecycle.error or "Service control requires an explicitly authorized matching local instance. Configure the exact unit and config path in Settings."
    local total = Model.totals(s)
    local variant, stateText = Model.indicator(s, controller.status)
    local prefix = controller.host.getConfig("brandedIcon") and "/assets/" or "/assets/mono/"
    local children = {
        ui.row({ gap = 8, align = "center" }, {
            ui.image({ path = controller.host.pluginDir() .. prefix .. "status-" .. variant .. ".svg", width = 28, height = 28 }),
            ui.column({ gap = 2, flexGrow = 1 }, {
                ui.label({ text = "Syncthing", fontWeight = "bold" }),
                ui.row({ gap = 6, align = "center" }, {
                    ui.label({ text = hostname, maxLines = 2, flexGrow = 1 }),
                    SharedWidgetControls.button("Copy ID", function()
                        controller:copy(identity.deviceId or "")
                    end, identity.deviceId ~= nil, nil, nil, "Copy this device's Syncthing ID"),
                }),
            }),
            ui.toggle({ checked = lifecycle.active == true, enabled = (lifecycle.canControl == true or (not lifecycle.active and lifecycle.canStart == true)) and not controller:busy(),
                onChange = function(value)
                    local enable = Model.bool(value)
                    controller:confirm(enable and "Start the authorized Syncthing service?" or "Stop the authorized Syncthing service?",
                        enable and "lifecycle.start" or "lifecycle.stop", {})
                end }),
        }),
        SharedWidgetControls.label(stateText, Palette.roles[variant == "notify" and "error"
            or ((variant == "sync" or variant == "pause") and "warning" or "success")]),
        InfoPair.render("Folders", counts.folders or 0),
        InfoPair.render("Devices", tostring(counts.connectedDevices or 0)
            .. " of " .. tostring(counts.devices or 0) .. " connected"),
        InfoPair.render("Tracked", tostring(total.files) .. " files | " .. Model.bytes(total.bytes)),
    }
    if total.scanning > 0 or total.paused > 0 then
        table.insert(children, InfoPair.render("Activity",
            tostring(total.scanning) .. " scanning | " .. tostring(total.paused) .. " paused"))
    end
    if controller.status.backgroundError then
        table.insert(children, SharedWidgetControls.notice(controller, controller.status.backgroundError
            .. "\nCheck plugin settings and the selected Web UI profile.", "error", "background action details"))
    end
    if connection.error then
        table.insert(children, SharedWidgetControls.notice(controller, connection.error.message .. "\nCheck connection and credential settings, then Refresh.", "error", "connection details"))
    elseif not connection.fresh then
        table.insert(children, SharedWidgetControls.label("Current status unavailable; last reported values shown", "error"))
    end
    if not lifecycle.canControl then
        if connection.online and not lifecycle.canStart and not lifecycle.error then
            table.insert(children, SharedWidgetControls.button("External instance", function()
                controller.view.details = { title = "Service control", text = reason }
                controller:save()
            end, true, "ghost", "service-details", reason))
        else
            table.insert(children, SharedWidgetControls.notice(controller, reason, "on_surface_variant", "service details"))
        end
    end
    return ui.column({ gap = 6 }, children)
end

return Header
