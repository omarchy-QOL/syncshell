local Ui = require("./UiConstants.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local SettingsMenu = {}

local function row(key, title, description, callback, color)
    return ui.column({ key = key, gap = 2, padding = 8, radius = 4, onClick = callback }, {
        ui.label({ text = title, fontSize = Ui.title, fontWeight = "bold", color = color or "on_surface", maxLines = 1 }),
        ui.label({ text = description, fontSize = Ui.body, color = "on_surface_variant", maxLines = 1 }),
    })
end

function SettingsMenu.render(controller)
    local form = controller.view.form
    return ui.column({ key = "settings-menu", gap = 4 }, {
        SharedWidgetControls.caption("SETTINGS"),
        row("settings-open", "Open settings file", "Edit icon and Web UI preferences", function() controller.host.openSettings() end),
        -- Omarchy applies these from its settings file; here they need the live service.
        row("settings-webui", "Web UI and service", "Apply the Web UI choice and review login state", function()
            form.page = "webui"; controller:save()
        end),
        row("settings-removal", "Cleanly remove Syncthing plugin", "Restore the default Web UI and remove owned profiles", function()
            form.page = "removal"; controller:save()
        end, "error"),
        ui.separator({}),
        row("settings-back", "Back [q]", "Return to Syncthing", function() controller:cancel() end),
    })
end

return SettingsMenu
