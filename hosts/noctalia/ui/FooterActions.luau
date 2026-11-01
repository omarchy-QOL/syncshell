local SharedWidgetControls = require("./SharedWidgetControls.luau")
local FooterActions = {}

function FooterActions.render(controller, enabled)
    return ui.column({ key = "footer-actions", gap = 8 }, {
        ui.row({ gap = 6 }, {
            SharedWidgetControls.button(controller:actionLabel("webui.open", "Web UI"), function() controller:send("webui.open", {}) end,
                enabled and (controller.snapshot.connection or {}).online, nil,
                controller:actionKey("webui"), "Open the selected Syncthing instance in your browser"),
            SharedWidgetControls.button("TUI", nil, false, nil, nil, "To be added soon."),
            SharedWidgetControls.button("GUI", nil, false, nil, nil, "To be added soon."),
        }),
        ui.row({ gap = 6 }, {
            SharedWidgetControls.button(controller:actionLabel("folder.rescan-all", "Rescan all"), function() controller:rescanAll() end,
                controller:canRescan(), nil, controller:actionKey("rescan-all"),
                "Rescan linked folders for local changes; requires a current connection and a folder not already scanning"),
            SharedWidgetControls.button(controller:actionLabel("folder.recheck-errors",
                controller:actionLabel("refresh", "Refresh")), function() controller:refresh() end,
                enabled, nil, controller:actionKey("refresh"),
                "Refresh Syncthing state, rescan folders with errors, or retry connection discovery"),
            SharedWidgetControls.button("Settings", function() controller:openForm("settings") end,
                not controller:busy(), nil, nil, "Syncshell settings"),
        }),
    })
end

return FooterActions
