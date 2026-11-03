local Palette = require("../controllers/ThemePaletteController.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local BodyFormHeader = require("./BodyFormHeader.luau")
local Removal = {}

function Removal.render(controller)
    local cleanup = controller.host.state.get("cleanup")
    local children = {
        BodyFormHeader.render(controller, "REMOVE SYNCTHING PLUGIN"),
    }
    -- Cleanup never stands in the way of removing the plugin.
    if (controller.snapshot.connection or {}).online ~= true then
        table.insert(children, SharedWidgetControls.label("1. Syncthing is not running, so its Web UI is left as it is. You can still remove the plugin."))
    else
        table.insert(children, SharedWidgetControls.label("1. Remove Noctalia's Web UI profiles. If one is selected, Syncthing returns to its default Web UI; any other theme stays. Synchronized files and other adapters' profiles remain."))
        table.insert(children, SharedWidgetControls.button("Remove Noctalia profiles", function()
            controller:confirm("Remove only Syncshell Noctalia's Web UI profiles? If one is selected, Syncthing returns to its default Web UI. Your synchronized files remain unchanged.",
                "webui.remove-profile", {})
        end, not controller:busy() and controller.status.ready, "destructive", "cleanup-profiles"))
        if controller.view.profilesRemoved then
            table.insert(children, SharedWidgetControls.label("Profile cleanup completed.", Palette.roles.success))
        end
    end
    for _, step in {
        SharedWidgetControls.label("2. Open Noctalia Settings, return to Plugins, and disable syncshell/syncshell. For a Git-source installation, use its Remove button. For a local copy or path source, remove only the package copy or link shown below after disabling it."),
        SharedWidgetControls.label(controller.host.pluginDir()),
        SharedWidgetControls.button("Copy package path", function() controller:copy(controller.host.pluginDir()) end),
        SharedWidgetControls.button("Open Noctalia for removal", function() controller.host.openSettings() end,
            not controller:busy(), "default", "remove-in-host"),
        SharedWidgetControls.label("3. Noctalia retains plugin settings. Keep them to reuse later, or remove only [plugin_settings.\"syncshell/syncshell\"] from your declarative config and resolved settings.toml overrides. Remove this plugin's bar placements through Noctalia's bar settings."),
        SharedWidgetControls.label("Settings overrides are in $NOCTALIA_STATE_HOME/noctalia/settings.toml, otherwise $XDG_STATE_HOME/noctalia/settings.toml, otherwise ~/.local/state/noctalia/settings.toml. Keep other plugins' settings and your Syncthing configuration."),
    } do table.insert(children, step) end
    if cleanup and cleanup.ready then
        table.insert(children, SharedWidgetControls.label("If the package was already removed, run the saved recovery command, then repeat the removal steps:\n" .. cleanup.path))
        table.insert(children, SharedWidgetControls.button("Copy cleanup path", function() controller:copy(cleanup.path) end))
        table.insert(children, SharedWidgetControls.label("After successful cleanup and plugin removal, its private recovery files may be removed from:\n" .. controller.host.pluginDataDir(), "on_surface_variant"))
    else
        table.insert(children, SharedWidgetControls.label("The saved recovery command is unavailable. Finish cleanup while the package remains installed.", "error"))
    end
    return ui.column({ gap = 8 }, children)
end

return Removal
