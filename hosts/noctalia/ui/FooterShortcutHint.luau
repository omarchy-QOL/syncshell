local SharedWidgetControls = require("./SharedWidgetControls.luau")
local FooterShortcutHint = {}

function FooterShortcutHint.render()
    return SharedWidgetControls.label("[r]escan [w]eb UI [p]ause/start [s]ettings [q]close | Tab: focus", "on_surface_variant")
end

return FooterShortcutHint
