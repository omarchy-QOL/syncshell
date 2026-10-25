local SharedWidgetControls = require("./SharedWidgetControls.luau")
local FooterActions = {}

function FooterActions.render(controller, enabled)
    return ui.row({ gap = 6 }, {
        SharedWidgetControls.button("Web UI", function() controller:send("webui.open", {}) end, enabled and (controller.snapshot.connection or {}).online, nil, controller:actionKey("webui"), "Open the selected Syncthing instance in your browser"),
        SharedWidgetControls.button("Rescan all", function() controller:rescanAll() end, controller:canRescan(), nil, controller:actionKey("rescan-all"), "Rescan linked folders for local changes; requires a current connection and a folder not already scanning"),
        SharedWidgetControls.button("Refresh", function() controller:refresh() end, enabled, nil, controller:actionKey("refresh"), "Refresh Syncthing state, rescan folders with errors, or retry connection discovery"),
        SharedWidgetControls.button("Settings", function() controller:openForm("settings") end, not controller:busy()),
    })
end

return FooterActions
