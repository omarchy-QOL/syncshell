local Ui = require("./UiConstants.luau")
local SharedWidgetControls = require("./SharedWidgetControls.luau")
local Model = require("../models/PanelModel.luau")
local Palette = require("../controllers/ThemePaletteController.luau")
local ActionButton = require("./SharedWidgetSquareActionButton.luau")
local Help = {}

function Help.render(controller)
    local s = controller.snapshot
    local installation, connection = s.installation or {}, s.connection or {}
    local text
    if connection.online then text = "Connected to Syncthing. " .. (installation.available and "Local executable found." or "No local executable found; the selected instance may be externally managed.")
    elseif installation.available then text = "Syncthing is installed but this connection is unavailable. Check the endpoint and credentials, or start it through its existing launcher."
    elseif installation.available == false then text = "No local Syncthing executable found. For a remote or container instance, configure its endpoint and credentials. For a local instance, install Syncthing through your distribution or the official downloads page."
    else text = "Installation status is not available yet. Refresh or check the worker error above." end
    local lifecycle = s.lifecycle or {}
    local summary = text .. "\nSyncthing " .. ((s.identity or {}).version or "version unavailable") .. " | " .. (connection.endpoint or "Endpoint not discovered")
    -- The switch is absent for an external instance, so say why here.
    if not lifecycle.canControl and not lifecycle.canStart and not lifecycle.error then
        summary ..= "\nExternal instance: service control requires an explicitly authorized matching local instance. Configure the exact unit and config path in Settings."
    end
    local row = ui.row({ gap = 8, align = "center" }, {
        SharedWidgetControls.caption("INSTALLATION"),
        ui.row({ tooltip = summary }, { ui.glyph({ name = "info-circle", size = Ui.title, color = installation.available and Palette.roles.success or Palette.roles.warning }) }),
        ui.label({ text = Model.shortPath(installation.executablePath or "—", 36), fontSize = Ui.bodySmall, maxLines = 1, flexGrow = 1 }),
        ActionButton.render("Installation help", "help", function() controller:openDocumentation("installation") end, true, nil,
            "Open Syncthing installation\nand removal documentation", Ui.control),
    })
    -- Omarchy's line under the row, for its own installer.
    if installation.available == false and not connection.online then
        return ui.column({ gap = 4 }, { row, SharedWidgetControls.hint("Install Syncthing with your package manager. Removal is manual.") })
    end
    return row
end

return Help
