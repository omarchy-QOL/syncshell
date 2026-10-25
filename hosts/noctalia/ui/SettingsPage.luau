local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local Service = require("./SettingsPageServiceControls.luau")
local Removal = require("./SettingsSelfRemovalSteps.luau")
local Settings = {}

function Settings.render(controller)
    local enabled = not controller:busy() and controller.status.ready
    local children = {
        SharedWidgetControls.formHeader(controller, "Settings and Web UI"),
        SharedWidgetControls.button("Open Noctalia plugin settings", function() controller.host.openSettings() end),
        SharedWidgetControls.label("Connection, refresh intervals, icon style and service authorization live in Noctalia's settings."),
        SharedWidgetControls.label("Preferred Web UI: " .. tostring(controller.host.getConfig("webUi"))
            .. " | Actual: " .. ((controller.snapshot.webUi or {}).theme or "Unknown")),
        SharedWidgetControls.button("Use Syncthing default", function()
            controller:confirm("Switch the shared Syncthing Web UI to its default theme?", "webui.set-theme", { theme = "default" })
        end, enabled),
        SharedWidgetControls.button("Use bundled Modern", function()
            controller:confirm("Install this adapter's Modern profile and select it for Syncthing?", "webui.apply-profile", { profile = "modern" })
        end, enabled),
        SharedWidgetControls.button("Use Noctalia colors", function()
            local colors, err = Palette.read(controller.host)
            if not colors then controller:notice(err, "error"); controller:save(); return end
            controller:confirm("Install this adapter's Web UI profile with Noctalia colors and select it for Syncthing?",
                "webui.apply-profile", { profile = "themed", palette = colors })
        end, enabled),
        SharedWidgetControls.button("Apply configured Web UI choice", function()
            local choice = controller.host.getConfig("webUi")
            local colors, err = Palette.read(controller.host)
            if choice == "themed" and not colors then controller:notice(err, "error"); controller:save(); return end
            controller:confirm("Apply the configured Web UI choice to the shared Syncthing instance?",
                choice == "default" and "webui.set-theme" or "webui.apply-profile",
                choice == "default" and { theme = "default" } or { profile = choice, palette = choice == "themed" and colors or nil })
        end, enabled),
        Service.render(controller),
        SharedWidgetControls.button(controller.view.removalOpen and "Hide removal steps" or "Removal and recovery", function()
            controller.view.removalOpen = not controller.view.removalOpen; controller:save()
        end),
    }
    if controller.view.removalOpen then table.insert(children, Removal.render(controller)) end
    return ui.column({ gap = 10 }, children)
end

return Settings
