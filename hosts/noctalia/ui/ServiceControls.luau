local Controls = require("./Controls.luau")
local Service = {}

function Service.render(controller)
    local lifecycle = controller.snapshot.lifecycle or {}
    local desired = controller.host.getConfig("serviceState")
    local actual = lifecycle.unitFileState or "unknown"
    local enabled = not controller:busy() and controller.status.ready and lifecycle.canControl == true
    local children = {
        Controls.label("Service at login", "on_surface_variant"),
        Controls.label("Preferred: " .. tostring(desired) .. " | Actual: " .. actual),
        Controls.label("Running now: " .. (lifecycle.activeState or (lifecycle.active and "active" or "unknown"))
            .. " | Unit: " .. (lifecycle.unit or "Not bound")),
    }
    local known = actual == "enabled" or actual == "disabled"
    local settled = lifecycle.activeState == "active" or lifecycle.activeState == "inactive"
    if not known or not settled then
        table.insert(children, Controls.label("Login state cannot be reconciled yet: the unit must report enabled or disabled and settle to active or inactive. Refresh or inspect the configured user service.", "on_surface_variant"))
    elseif actual ~= desired then
        table.insert(children, Controls.label("The login preference and service state differ. Choose which to keep."))
        table.insert(children, Controls.button("Apply preferred login state", function()
            controller:confirm("Set " .. (lifecycle.unit or "the authorized user service") .. " to " .. desired
                .. " at login? This does not start or stop the running daemon.",
                desired == "enabled" and "lifecycle.enable" or "lifecycle.disable", {})
        end, enabled, "primary", "apply-service-state"))
        table.insert(children, Controls.label("To keep the actual service state, change Preferred service at login to "
            .. actual .. " in Noctalia plugin settings.", "on_surface_variant"))
        table.insert(children, Controls.button("Change preference in Noctalia", function() controller.host.openSettings() end))
    end
    if not lifecycle.canControl then
        table.insert(children, Controls.label(lifecycle.error or "This instance is externally managed or its exact service binding is not authorized. Use its existing launcher, or configure the matching unit and config path in Noctalia settings.", "on_surface_variant"))
    end
    table.insert(children, Controls.label("Enabling this plugin does not authorize or enable Syncthing's service.", "on_surface_variant"))
    return ui.column({ gap = 8 }, children)
end

return Service
