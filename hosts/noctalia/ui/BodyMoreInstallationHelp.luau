local SharedWidgetControls = require("./SharedWidgetControls.luau")
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
    local children = {
        ui.row({ gap = 8, align = "center" }, {
            SharedWidgetControls.caption("INSTALLATION"),
            ui.glyph({ name = "info-circle", size = 14, color = installation.available and Palette.roles.success or Palette.roles.warning }),
            ui.label({ text = installation.executablePath or "Executable not found", fontSize = 12, maxLines = 1, flexGrow = 1 }),
            ActionButton.render("Installation help", "help", function() controller:openDocumentation("installation") end, true, nil, "Installation help", 26),
        }),
        SharedWidgetControls.hint(text),
        SharedWidgetControls.hint("Syncthing " .. ((s.identity or {}).version or "version unavailable") .. " | " .. (connection.endpoint or "Endpoint not discovered")),
    }
    if not lifecycle.canControl and connection.online and not lifecycle.canStart and not lifecycle.error then
        table.insert(children, SharedWidgetControls.button("External instance", function()
            controller.view.details = { title = "Service control", text = "Service control requires an explicitly authorized matching local instance. Configure the exact unit and config path in Settings." }
            controller:save()
        end, true, "ghost", "service-details", "Service control requires an explicitly authorized matching local instance."))
    end
    table.insert(children, ui.row({ gap = 6 }, {
        SharedWidgetControls.button("Startup help", function() controller:openDocumentation("startup") end, true, "outline"),
        SharedWidgetControls.button("Connection and service settings", function() controller.host.openSettings() end, true, "outline"),
    }))
    return ui.column({ gap = 6 }, children)
end

return Help
