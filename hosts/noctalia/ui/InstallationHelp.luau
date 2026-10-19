local Controls = require("./Controls.luau")
local Help = {}

function Help.render(controller)
    local s = controller.snapshot
    local installation, connection = s.installation or {}, s.connection or {}
    local text
    if connection.online then text = "Connected to Syncthing. " .. (installation.available and "Local executable found." or "No local executable found; the selected instance may be externally managed.")
    elseif installation.available then text = "Syncthing is installed but this connection is unavailable. Check the endpoint and credentials, or start it through its existing launcher."
    elseif installation.available == false then text = "No local Syncthing executable found. For a remote or container instance, configure its endpoint and credentials. For a local instance, install Syncthing through your distribution or the official downloads page."
    else text = "Installation status is not available yet. Refresh or check the worker error above." end
    return ui.column({ gap = 6 }, {
        Controls.label("Installation and recovery"), Controls.label(text),
        ui.row({ gap = 6 }, {
            Controls.button("Installation help", function() controller:openDocumentation("installation") end),
            Controls.button("Startup help", function() controller:openDocumentation("startup") end),
        }),
        Controls.button("Connection and service settings", function() controller.host.openSettings() end),
        Controls.label("After installing or repairing Syncthing, Refresh to check again. Use the original package manager or launcher for Syncthing removal; removing this plugin does not uninstall Syncthing or delete synchronized data.", "on_surface_variant"),
    })
end

return Help
