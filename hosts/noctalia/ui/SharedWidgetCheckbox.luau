local Ui = require("./UiConstants.luau")
local Checkbox = {}

-- The host's only boolean control is a switch; Omarchy's pickers use check
-- boxes and radio dots.
function Checkbox.render(key, label, checked, toggle, enabled, help, radio, detail)
    enabled = enabled ~= false
    local mark = radio and ui.box({ width = 8, height = 8, radius = 4, fill = "primary", visible = checked })
        or ui.glyph({ name = "check", size = 12, color = "on_primary", visible = checked })
    local text = { ui.label({ text = label, fontSize = Ui.body, maxLines = 1 }) }
    if detail then table.insert(text, ui.label({ text = detail, color = "on_surface_variant", fontSize = Ui.caption, maxLines = 2 })) end
    return ui.row({ key = key, gap = 8, align = "center", minHeight = 24, paddingH = 4, radius = 4, flexGrow = 1, tooltip = help,
        opacity = enabled and 1 or 0.5, onClick = enabled and toggle or nil }, {
        ui.row({ width = 16, height = 16, align = "center", justify = "center", radius = radio and 8 or 3, borderWidth = 1,
            border = checked and "primary" or "outline", fill = (checked and not radio) and "primary" or "#00000000" }, { mark }),
        ui.column({ flexGrow = 1, minWidth = 0 }, text),
    })
end

return Checkbox
