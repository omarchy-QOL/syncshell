local SharedWidgetControls = require("./SharedWidgetControls.luau")
local ActionButton = require("./SharedWidgetSquareActionButton.luau")
local FooterActions = {}

local function action(key, text, glyph, callback, enabled, help)
    return ui.button({ key = key, text = text, glyph = glyph, controlSize = "sm", fontSize = 12, glyphSize = 14,
        variant = "outline", enabled = enabled ~= false, tooltip = help, onClick = callback, flexGrow = glyph and 1 or nil })
end

function FooterActions.render(controller, enabled)
    return ui.column({ key = "footer-actions", gap = 8 }, {
        ui.row({ gap = 6 }, {
            action(controller:actionKey("webui"), controller:actionLabel("webui.open", "Web UI"), nil, function() controller:send("webui.open", {}) end,
                enabled and (controller.snapshot.connection or {}).online, "Open the selected Syncthing instance in your browser"),
            action("TUI", "TUI", nil, nil, false, "To be added soon."),
            action("GUI", "GUI", nil, nil, false, "To be added soon."),
        }),
        ui.row({ gap = 6 }, {
            action(controller:actionKey("rescan-all"), controller:actionLabel("folder.rescan-all", "Rescan all folders"), "refresh",
                function() controller:rescanAll() end, controller:canRescan(),
                "Rescan linked folders for local changes; requires a current connection and a folder not already scanning"),
            action(controller:actionKey("refresh"), controller:actionLabel("folder.recheck-errors", controller:actionLabel("refresh", "Refresh Sync.status")),
                "activity-heartbeat", function() controller:refresh() end, enabled,
                "Refresh Syncthing state, rescan folders with errors, or retry connection discovery"),
            ActionButton.render("Settings", "settings", function() controller:openForm("settings") end,
                not controller:busy(), nil, "Settings"),
        }),
    })
end

return FooterActions
