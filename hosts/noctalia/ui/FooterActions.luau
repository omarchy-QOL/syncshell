local Ui = require("./UiConstants.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local ActionButton = require("./SharedWidgetSquareActionButton.luau")
local FooterActions = {}

local function action(key, text, glyph, callback, enabled, help)
    return ui.button({ key = key, text = text, glyph = glyph, height = Ui.control, fontSize = Ui.body, glyphSize = glyph and Ui.body or nil,
        variant = "outline", enabled = enabled ~= false, tooltip = help, onClick = callback, flexGrow = glyph and 1 or nil })
end

function FooterActions.render(controller, enabled)
    return ui.column({ key = "footer-actions", gap = 8 }, {
        ui.row({ gap = 6 }, {
            action(controller:actionKey("webui"), controller:actionLabel("webui.open", "Web UI"), nil, function() controller:openWebUi() end,
                (controller.snapshot.connection or {}).online == true, "Open the Syncthing Web UI"),
            action("TUI", "TUI", nil, nil, false, "To be added soon."),
            action("GUI", "GUI", nil, nil, false, "To be added soon."),
        }),
        ui.row({ gap = 6 }, {
            action(controller:actionKey("rescan-all"), controller:actionLabel("folder.rescan-all", "Rescan all folders", "Rescanning..."), "rotate-clockwise",
                function() controller:rescanAll() end, controller:canRescan(),
                "Rescan all folders for local changes."),
            action(controller:actionKey("refresh"), controller:refreshing() and "Rechecking Syncthing" or "Refresh Sync.status",
                "heartbeat", function() controller:refresh() end, controller:canRefresh(),
                "Request latest Syncthing state.\nActive folders with current errors\nrescanned and errors rechecked."),
            ActionButton.render("Settings", "settings-filled", function() controller:openForm("settings") end,
                true, nil, "Settings"),
        }),
    })
end

return FooterActions
