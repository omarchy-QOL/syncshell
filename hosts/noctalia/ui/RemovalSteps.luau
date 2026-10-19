local Controls = require("./Controls.luau")
local Removal = {}

function Removal.render(controller)
    local cleanup = controller.host.state.get("cleanup")
    local children = {
        Controls.label("Remove Syncshell from Noctalia"),
        Controls.label("1. Restore the default Web UI and remove Noctalia's owned profiles. Synchronized files and other adapters' profiles remain."),
        Controls.button("Restore default and remove Noctalia profiles", function()
            controller:confirm("Restore Syncthing's default Web UI and remove only Syncshell Noctalia's profiles? Your synchronized files remain unchanged.",
                "webui.remove-profile", {})
        end, not controller:busy() and controller.status.ready, "destructive", "cleanup-profiles"),
        Controls.label(controller.view.profilesRemoved and "Profile cleanup completed. You can now remove the plugin."
            or "Complete cleanup before deleting or disabling this plugin; if it fails, correct the reported problem and retry.",
            controller.view.profilesRemoved and "tertiary" or "on_surface_variant"),
        Controls.label("2. Open Noctalia Settings, return to Plugins, and disable syncshell/syncshell. For a Git-source installation, use its Remove button. For a local copy or path source, remove only the package copy or link shown below after disabling it."),
        Controls.label(controller.host.pluginDir()),
        Controls.button("Copy package path", function() controller:copy(controller.host.pluginDir()) end),
        Controls.button("Open Noctalia for removal", function() controller.host.openSettings() end,
            controller.view.profilesRemoved == true and not controller:busy(), "default", "remove-in-host"),
        Controls.label("3. Noctalia retains plugin settings. Keep them to reuse later, or remove only [plugin_settings.\"syncshell/syncshell\"] from your declarative config and resolved settings.toml overrides. Remove this plugin's bar placements through Noctalia's bar settings."),
        Controls.label("Settings overrides are in $NOCTALIA_STATE_HOME/noctalia/settings.toml, otherwise $XDG_STATE_HOME/noctalia/settings.toml, otherwise ~/.local/state/noctalia/settings.toml. Keep other plugins' settings and your Syncthing configuration."),
    }
    if cleanup and cleanup.ready then
        table.insert(children, Controls.label("If the package was already removed, run the saved recovery command, then repeat the removal steps:\n" .. cleanup.path))
        table.insert(children, Controls.button("Copy cleanup path", function() controller:copy(cleanup.path) end))
        table.insert(children, Controls.label("After successful cleanup and plugin removal, its private recovery files may be removed from:\n" .. controller.host.pluginDataDir(), "on_surface_variant"))
    else
        table.insert(children, Controls.label("The saved recovery command is unavailable. Finish cleanup while the package remains installed.", "error"))
    end
    return ui.column({ gap = 8 }, children)
end

return Removal
