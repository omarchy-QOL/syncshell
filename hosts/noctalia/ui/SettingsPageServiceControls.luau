local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Service = {}

-- Status only: a disagreement between preference and systemd opens Omarchy's
-- choice dialog instead.
function Service.render(controller)
    local lifecycle = controller.snapshot.lifecycle or {}
    return ui.column({ gap = 4 }, {
        SharedWidgetControls.caption("SERVICE AT LOGIN"),
        SharedWidgetControls.label("Preferred: " .. tostring(controller.host.getConfig("serviceState")) .. " | Actual: " .. (lifecycle.unitFileState or "unknown")),
        SharedWidgetControls.label("Running now: " .. (lifecycle.activeState or (lifecycle.active and "active" or "unknown"))
            .. " | Unit: " .. (lifecycle.unit or "Not bound")),
    })
end

return Service
