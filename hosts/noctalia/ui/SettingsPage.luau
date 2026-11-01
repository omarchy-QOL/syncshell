local SharedWidgetControls = require("./SharedWidgetControls.luau")
local BodyFormHeader = require("./BodyFormHeader.luau")
local Service = require("./SettingsPageServiceControls.luau")
-- Status only: the Web UI follows the settings file, as in Omarchy.
local Settings = {}

function Settings.render(controller)
        local children = {
        BodyFormHeader.render(controller, "WEB UI AND SERVICE"),
        SharedWidgetControls.label("Preferred Web UI: " .. tostring(controller.host.getConfig("webUi"))
            .. " | Actual: " .. ((controller.snapshot.webUi or {}).theme or "Unknown")),
        Service.render(controller),
    }
    return ui.column({ gap = 8 }, children)
end

return Settings
