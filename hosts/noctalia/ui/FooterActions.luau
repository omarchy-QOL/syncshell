local Ui = require("./UiConstants.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local ActionButton = require("./SharedWidgetSquareActionButton.luau")
local BusyIcon = require("./SharedWidgetBusyIcon.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local FooterActions = {}

-- Omarchy's busy footer buttons turn warning-colored around an animated icon.
local function busy(key, text, icon, help)
    local node = SharedWidgetControls.tinted(key, text, icon, Palette.roles.warning, nil, true, help, Ui.control)
    node.props.flexGrow, node.props.justify = 1, "center"
    return node
end

local function action(key, text, glyph, callback, enabled, help, grow)
    return ui.button({ key = key, text = text, glyph = glyph, height = Ui.control, fontSize = Ui.body, glyphSize = glyph and Ui.body or nil,
        variant = "outline", enabled = enabled ~= false, tooltip = help, flexGrow = grow, onClick = callback })
end

function FooterActions.render(controller, enabled)
    return ui.column({ key = "footer-actions", gap = 8 }, {
        ui.row({ gap = 6 }, {
            action(controller:actionKey("webui"), controller:actionLabel("webui.open", "Web UI"), nil, function() controller:openWebUi() end,
                -- Omarchy's stays bright while offline; openWebUi ignores the click.
                true, "Open the Syncthing Web UI"),
            action("TUI", "TUI", nil, nil, false, "To be added soon."),
            action("GUI", "GUI", nil, nil, false, "To be added soon."),
        }),
        ui.row({ gap = 6 }, {
            (controller:rescanState() or {}).action == "folder.rescan-all"
                and busy(controller:actionKey("rescan-all"), "Rescanning...", BusyIcon.spin(controller, "rescan", Palette.roles.warning, "rotate-clockwise"),
                    "Rescan all folders for local changes.")
                or action(controller:actionKey("rescan-all"), "Rescan all folders", "rotate-clockwise",
                    function() controller:rescanAll() end, controller:canRescan(),
                    "Rescan all folders for local changes.", 1),
            controller:refreshing()
                and busy(controller:actionKey("refresh"), "Rechecking Syncthing", BusyIcon.pulse(controller, "heartbeat", Palette.roles.warning),
                    "Request latest Syncthing state.\nActive folders with current errors\nrescanned and errors rechecked.")
                or action(controller:actionKey("refresh"), "Refresh Sync.status", "heartbeat", function() controller:refresh() end, controller:canRefresh(),
                    "Request latest Syncthing state.\nActive folders with current errors\nrescanned and errors rechecked.", 1),
            ActionButton.render("Settings", "settings-filled", function() controller:openForm("settings") end,
                true, nil, "Settings"),
        }),
    })
end

return FooterActions
