local Controls = require("./Controls.luau")
local Model = require("../models/PanelModel.luau")
local Status = {}

function Status.render(controller)
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
            ui.label({ text = "Syncthing | " .. hostname, maxLines = 2 }),
            Controls.button("Copy ID", function() controller:copy(identity.deviceId or "") end, identity.deviceId ~= nil),
        }),
        ui.row({ gap = 8, align = "center" }, {
            Controls.label(stateText, variant == "notify" and "error" or "tertiary"),
            ui.toggle({ checked = lifecycle.active == true, enabled = (lifecycle.canControl == true or (not lifecycle.active and lifecycle.canStart == true)) and not controller:busy(),
                onChange = function(value)
                    local enable = Model.bool(value)
                    controller:confirm(enable and "Start the authorized Syncthing service?" or "Stop the authorized Syncthing service?",
                        enable and "lifecycle.start" or "lifecycle.stop", {})
                end }),
            Controls.label("Service"),
        }),
        Controls.label(tostring(counts.folders or 0) .. " folders | " .. tostring(counts.connectedDevices or 0)
            .. "/" .. tostring(counts.devices or 0) .. " devices connected", "on_surface_variant"),
    }
    table.insert(children, Controls.label(tostring(total.files) .. " files | " .. Model.bytes(total.bytes)
        .. " tracked | " .. tostring(total.scanning) .. " scanning | " .. tostring(total.paused) .. " paused", "on_surface_variant"))
    if controller.status.backgroundError then
        table.insert(children, Controls.notice(controller, controller.status.backgroundError
            .. "\nCheck plugin settings and the selected Web UI profile.", "error", "background action details"))
    end
    if connection.error then
        table.insert(children, Controls.notice(controller, connection.error.message .. "\nCheck connection and credential settings, then Refresh.", "error", "connection details"))
    elseif not connection.fresh then
        table.insert(children, Controls.label("Current status unavailable; last reported values shown", "error"))
    end
    if not lifecycle.canControl then table.insert(children, Controls.notice(controller, reason, "on_surface_variant", "service details")) end
    return ui.column({ gap = 6 }, children)
end

return Status
